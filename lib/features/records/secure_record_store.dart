import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashing;
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'record_ports.dart';

/// What [MedicineStore], [DoseLogStore] and [VisitRepository] read and write.
///
/// One document, sealed as a whole. A failed decrypt does not apply half of it.
abstract class VaultBox {
  String? read(String key);
  Future<void> write(String key, String? value);
}

/// Keys that used to live in shared_preferences as plain medical JSON.
/// Device choices (language, voice, role, PIN hash, pairing) are not here.
abstract final class MedicalKeys {
  static const medicines = 'scheduled_medicines';
  static const records = 'prescription_records';
  static const doses = 'dose_logs';
  static const visit = 'visit_draft';
  static const all = [medicines, records, doses, visit];
}

/// Why a file was not loaded. The file itself is left where it was.
enum VaultFault { none, corrupt, tampered }

enum RestoreResult { ok, wrongPin, tampered, corrupt, nothing }

/// AES-256-GCM records, a keystore data key, and a PIN wrap for the backup.
class SecureRecordStore implements VaultBox {
  SecureRecordStore._({
    required SharedPreferences prefs,
    required KeyBox keys,
    required RecordFile file,
    required BackupSink backup,
    required this.kdfIterations,
    required DateTime Function() clock,
  }) : _prefs = prefs,
       _keys = keys,
       _file = file,
       _backup = backup,
       _clock = clock;

  /// OWASP's PBKDF2-SHA256 count. Tests inject a far smaller one.
  static const productionKdfIterations = 600000;

  final SharedPreferences _prefs;
  final KeyBox _keys;
  final RecordFile _file;
  final BackupSink _backup;
  final DateTime Function() _clock;

  /// Rounds used the next time the PIN wraps the data key. Restore reads the
  /// count stored beside the blob, not this.
  final int kdfIterations;

  final _aes = AesGcm.with256bits();
  final _random = Random.secure();

  Map<String, String> _fields = {};
  Uint8List? _dataKey;
  Uint8List? _lastFile;
  String? _createdAt;
  _Wrap? _wrap;
  VaultFault fault = VaultFault.none;

  /// When false, persist still updates the working copy but does not replace
  /// a backup that was already there (the demo must not eat a real file).
  bool mirrorBackup = true;

  static SecureRecordStore? _live;
  static Future<SecureRecordStore>? _gate;

  bool get hasRecords => MedicalKeys.all.any(_fields.containsKey);

  BackupSink get backup => _backup;

  /// Drop the cached store. Tests call this between cases.
  static void debugReset() {
    _live = null;
    _gate = null;
  }

  static Future<SecureRecordStore> open({
    SharedPreferences? prefs,
    KeyBox? keyBox,
    RecordFile? file,
    BackupSink? backup,
    int? kdfIterations,
    DateTime Function()? clock,
  }) {
    // A clock is not a separate store: the app and the check screen must
    // share the one that [MedicineStore.load] will see.
    final injected =
        prefs != null || keyBox != null || file != null || backup != null;
    if (injected) {
      return _start(
        prefs: prefs,
        keyBox: keyBox,
        file: file,
        backup: backup,
        kdfIterations: kdfIterations,
        clock: clock,
      );
    }
    return _gate ??= _start(kdfIterations: kdfIterations)
        .whenComplete(() => _gate = null);
  }

  static Future<SecureRecordStore> _start({
    SharedPreferences? prefs,
    KeyBox? keyBox,
    RecordFile? file,
    BackupSink? backup,
    int? kdfIterations,
    DateTime Function()? clock,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final live = _live;
    final hooked = keyBox != null || file != null || backup != null;
    if (!hooked &&
        live != null &&
        identical(live._prefs, resolvedPrefs) &&
        await live._matchesDisk()) {
      return live;
    }
    final store = SecureRecordStore._(
      prefs: resolvedPrefs,
      keys: keyBox ?? RecordHooks.keyBox ?? createKeyBox(),
      file: file ?? RecordHooks.file ?? createRecordFile(resolvedPrefs),
      backup: backup ?? RecordHooks.backup ?? createBackupSink(),
      kdfIterations:
          kdfIterations ?? RecordHooks.kdfIterations ?? defaultKdfIterations(),
      clock: clock ?? RecordHooks.clock ?? DateTime.now,
    );
    await store._load();
    if (!hooked && prefs == null) _live = store;
    return store;
  }

  @override
  String? read(String key) => _fields[key];

  @override
  Future<void> write(String key, String? value) async {
    final previous = _fields[key];
    if (value == null) {
      _fields.remove(key);
    } else {
      _fields[key] = value;
    }
    try {
      await _persist();
    } catch (e) {
      if (previous == null) {
        _fields.remove(key);
      } else {
        _fields[key] = previous;
      }
      rethrow;
    }
  }

  /// Wrap the same data key with [pin]. The records are not re-keyed; a new
  /// nonce is still used for the write. Call this whenever the PIN changes.
  Future<void> rewrap(String pin) async {
    _dataKey ??= await _newKey();
    await _keys.write(_dataKey!);
    _wrap = await _wrapKey(_dataKey!, pin);
    await _persist();
  }

  /// Open a backup (or fail). Wrong PIN and a tampered box leave the files
  /// and the in-memory records untouched.
  Future<RestoreResult> restore(String pin) async {
    final copy = await _backup.read();
    if (copy == null) return RestoreResult.nothing;
    final env = _Envelope.tryParse(copy.vault);
    if (env == null || env.wrap == null) return RestoreResult.corrupt;
    try {
      final key = await _unwrap(env.wrap!, pin);
      final clear = await _decrypt(env, key);
      final fields = _fieldsFromClear(clear);
      _fields = fields;
      _dataKey = key;
      _wrap = env.wrap;
      _createdAt = env.createdAt;
      fault = VaultFault.none;
      await _keys.write(key);
      await _file.write(copy.vault);
      _lastFile = Uint8List.fromList(copy.vault);
      return RestoreResult.ok;
    } on _WrongPin {
      return RestoreResult.wrongPin;
    } on _Tampered {
      return RestoreResult.tampered;
    } on FormatException {
      return RestoreResult.corrupt;
    }
  }

  /// Forget the working copy. [andBackup] is for leaving a demo that wrote
  /// the mirror; a declined restore never calls this.
  Future<void> wipe({bool andBackup = false}) async {
    _fields = {};
    _wrap = null;
    _createdAt = null;
    _dataKey = null;
    _lastFile = null;
    fault = VaultFault.none;
    await _file.delete();
    await _keys.delete();
    if (andBackup) await _backup.delete();
  }

  Future<void> _load() async {
    final bytes = await _file.read();
    final plain = _plainPrefs();
    if (bytes == null || bytes.isEmpty) {
      _dataKey = await _keys.read() ?? await _newKey();
      await _keys.write(_dataKey!);
      if (plain.isNotEmpty) {
        _fields = plain;
        await _persist();
        await _deletePlain();
      }
      return;
    }
    final env = _Envelope.tryParse(bytes);
    if (env == null) {
      fault = VaultFault.corrupt;
      _lastFile = Uint8List.fromList(bytes);
      _fields = {};
      return;
    }
    final key = await _keys.read();
    if (key == null) {
      // Sealed. The restore screen unwraps it; do not start an empty record
      // over the top.
      _lastFile = Uint8List.fromList(bytes);
      _createdAt = env.createdAt;
      _wrap = env.wrap;
      return;
    }
    try {
      final clear = await _decrypt(env, key);
      _fields = _fieldsFromClear(clear);
      _dataKey = key;
      _createdAt = env.createdAt;
      _wrap = env.wrap;
      _lastFile = Uint8List.fromList(bytes);
      fault = VaultFault.none;
      if (plain.isNotEmpty) await _deletePlain();
    } on _Tampered {
      fault = VaultFault.tampered;
      _lastFile = Uint8List.fromList(bytes);
      _fields = {};
    } on FormatException {
      fault = VaultFault.corrupt;
      _lastFile = Uint8List.fromList(bytes);
      _fields = {};
    }
  }

  Future<void> _persist() async {
    final key = _dataKey ??= await _newKey();
    await _keys.write(key);
    final now = _clock().toIso8601String();
    _createdAt ??= now;
    final bytes = await _seal(
      fields: _fields,
      dataKey: key,
      wrap: _wrap,
      createdAt: _createdAt!,
      updatedAt: now,
    );
    await _file.write(bytes);
    _lastFile = bytes;
    if (mirrorBackup && hasRecords) {
      await _backup.write(bytes, _manifest(now));
    }
  }

  RecordManifest _manifest(String updatedAt) => RecordManifest(
    createdAt: _createdAt!,
    updatedAt: updatedAt,
    counts: {
      'medicines': _count(MedicalKeys.medicines),
      'prescriptions': _count(MedicalKeys.records),
      'doseLogs': _count(MedicalKeys.doses),
      'visits': _fields.containsKey(MedicalKeys.visit) ? 1 : 0,
    },
    phoneHash: _phoneHash(_prefs.getString('phone_number')),
  );

  int _count(String key) {
    final raw = _fields[key];
    if (raw == null) return 0;
    try {
      final value = jsonDecode(raw);
      return value is List ? value.length : 1;
    } catch (_) {
      return 0;
    }
  }

  Map<String, String> _plainPrefs() {
    final found = <String, String>{};
    for (final key in MedicalKeys.all) {
      final value = _prefs.getString(key);
      if (value != null) found[key] = value;
    }
    return found;
  }

  Future<void> _deletePlain() async {
    for (final key in MedicalKeys.all) {
      await _prefs.remove(key);
    }
  }

  Future<bool> _matchesDisk() async {
    final now = await _file.read();
    return _same(now, _lastFile);
  }

  Future<Uint8List> _newKey() async {
    final key = Uint8List(32);
    for (var i = 0; i < key.length; i++) {
      key[i] = _random.nextInt(256);
    }
    return key;
  }

  Uint8List _randomBytes(int n) {
    final bytes = Uint8List(n);
    for (var i = 0; i < n; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  Future<_Wrap> _wrapKey(Uint8List dataKey, String pin) async {
    final salt = _randomBytes(16);
    final kek = await _derive(pin, salt, kdfIterations);
    final box = await _aes.encrypt(
      dataKey,
      secretKey: kek,
      nonce: _aes.newNonce(),
    );
    return _Wrap(
      salt: salt,
      iterations: kdfIterations,
      nonce: Uint8List.fromList(box.nonce),
      cipher: Uint8List.fromList(box.cipherText),
      mac: Uint8List.fromList(box.mac.bytes),
    );
  }

  Future<Uint8List> _unwrap(_Wrap wrap, String pin) async {
    final kek = await _derive(pin, wrap.salt, wrap.iterations);
    try {
      final clear = await _aes.decrypt(
        SecretBox(wrap.cipher, nonce: wrap.nonce, mac: Mac(wrap.mac)),
        secretKey: kek,
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const _WrongPin();
    }
  }

  Future<SecretKey> _derive(String pin, List<int> salt, int iterations) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
  }

  Future<List<int>> _decrypt(_Envelope env, Uint8List dataKey) async {
    try {
      return await _aes.decrypt(
        SecretBox(env.cipher, nonce: env.nonce, mac: Mac(env.mac)),
        secretKey: SecretKey(dataKey),
      );
    } on SecretBoxAuthenticationError {
      throw const _Tampered();
    }
  }

  Future<Uint8List> _seal({
    required Map<String, String> fields,
    required Uint8List dataKey,
    required _Wrap? wrap,
    required String createdAt,
    required String updatedAt,
  }) async {
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(fields)),
      secretKey: SecretKey(dataKey),
      nonce: _aes.newNonce(),
    );
    final json = <String, Object?>{
      'v': 1,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
      if (wrap != null) ...wrap.toJson(),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(json)));
  }

  Map<String, String> _fieldsFromClear(List<int> clear) {
    final decoded = jsonDecode(utf8.decode(clear));
    if (decoded is! Map) throw const FormatException('vault');
    final fields = <String, String>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('vault');
      }
      fields[entry.key as String] = entry.value as String;
    }
    return fields;
  }
}

/// True when [bytes] are a sealed vault a PIN can unwrap. A broken file,
/// or one saved before any PIN wrap, is not.
bool backupCanUnlock(Uint8List bytes) {
  final env = _Envelope.tryParse(bytes);
  return env != null && env.wrap != null;
}

String? _phoneHash(String? phone) {
  if (phone == null || phone.isEmpty) return null;
  return hashing.sha256.convert(utf8.encode('rapidrx-phone:$phone')).toString();
}

bool _same(Uint8List? a, Uint8List? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class _WrongPin implements Exception {
  const _WrongPin();
}

class _Tampered implements Exception {
  const _Tampered();
}

class _Wrap {
  const _Wrap({
    required this.salt,
    required this.iterations,
    required this.nonce,
    required this.cipher,
    required this.mac,
  });

  final Uint8List salt;
  final int iterations;
  final Uint8List nonce;
  final Uint8List cipher;
  final Uint8List mac;

  Map<String, Object?> toJson() => {
    'salt': base64Encode(salt),
    'iterations': iterations,
    'wrapNonce': base64Encode(nonce),
    'wrapped': base64Encode(cipher),
    'wrapMac': base64Encode(mac),
  };

  static _Wrap? tryParse(Map<String, Object?> json) {
    final salt = _b64(json['salt']);
    final nonce = _b64(json['wrapNonce']);
    final cipher = _b64(json['wrapped']);
    final mac = _b64(json['wrapMac']);
    final iterations = json['iterations'];
    if (salt == null ||
        nonce == null ||
        cipher == null ||
        mac == null ||
        iterations is! int) {
      return null;
    }
    return _Wrap(
      salt: salt,
      iterations: iterations,
      nonce: nonce,
      cipher: cipher,
      mac: mac,
    );
  }
}

class _Envelope {
  const _Envelope({
    required this.createdAt,
    required this.nonce,
    required this.cipher,
    required this.mac,
    this.wrap,
  });

  final String createdAt;
  final Uint8List nonce;
  final Uint8List cipher;
  final Uint8List mac;
  final _Wrap? wrap;

  static _Envelope? tryParse(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) return null;
      final json = decoded.cast<String, Object?>();
      if (json['v'] != 1) return null;
      final created = json['createdAt'];
      final nonce = _b64(json['nonce']);
      final cipher = _b64(json['ciphertext']);
      final mac = _b64(json['mac']);
      if (created is! String ||
          nonce == null ||
          cipher == null ||
          mac == null) {
        return null;
      }
      final hasWrap = json.containsKey('wrapped');
      final wrap = hasWrap ? _Wrap.tryParse(json) : null;
      if (hasWrap && wrap == null) return null;
      return _Envelope(
        createdAt: created,
        nonce: nonce,
        cipher: cipher,
        mac: mac,
        wrap: wrap,
      );
    } catch (_) {
      return null;
    }
  }
}

Uint8List? _b64(Object? value) {
  if (value is! String || value.isEmpty) return null;
  try {
    return base64Decode(value);
  } catch (_) {
    return null;
  }
}
