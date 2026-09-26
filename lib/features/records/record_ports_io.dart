import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'record_ports.dart';

/// Tests never touch a keystore or MediaStore. `FLUTTER_TEST` is set by the
/// runner and is absent from `flutter run`.
bool get _underTest => Platform.environment.containsKey('FLUTTER_TEST');

KeyBox createKeyBox() => _underTest ? MemoryKeyBox.shared : SecureKeyBox();

RecordFile createRecordFile(SharedPreferences prefs) =>
    _underTest ? PrefsRecordFile(prefs) : DiskRecordFile();

BackupSink createBackupSink() =>
    _underTest ? MemoryBackupSink() : MediaStoreBackupSink();

/// Production PBKDF2 is slow on purpose. The suite does not pass a count into
/// every open(), so under the test runner this is the low default. A real
/// launch does not set FLUTTER_TEST. Pass RecordHooks.kdfIterations (or the
/// kdfIterations argument) to inject another count; the envelope stores
/// whichever count wrapped the key.
int defaultKdfIterations() => _underTest ? 1000 : 600000;

/// The data key, in the platform keystore. Not used under the test runner.
class SecureKeyBox implements KeyBox {
  static const _key = 'rapidrx.data_key';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<Uint8List?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    return base64Decode(raw);
  }

  @override
  Future<void> write(Uint8List key) =>
      _storage.write(key: _key, value: base64Encode(key));

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

/// Ciphertext in preferences, for the test runner only. The phone keeps the
/// working copy in [DiskRecordFile]. This key is not a medical record: it is
/// the sealed blob, and [setMockInitialValues] clears it with the rest.
class PrefsRecordFile implements RecordFile {
  PrefsRecordFile(this.prefs);

  final SharedPreferences prefs;
  static const key = 'vault_blob';

  @override
  Future<Uint8List?> read() async {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    return base64Decode(raw);
  }

  @override
  Future<void> write(Uint8List bytes) =>
      prefs.setString(key, base64Encode(bytes));

  @override
  Future<void> delete() => prefs.remove(key);
}

/// App-private working copy. Uninstall removes it; the MediaStore mirror is
/// what a reinstall can find.
class DiskRecordFile implements RecordFile {
  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/records.vault');
  }

  @override
  Future<Uint8List?> read() async {
    final file = await _file();
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> write(Uint8List bytes) async {
    final file = await _file();
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> delete() async {
    final file = await _file();
    if (file.existsSync()) await file.delete();
  }
}

/// Documents/RapidRX via the Android channel. No MANAGE_EXTERNAL_STORAGE.
/// Desktop has no channel: read is "nothing found", write is a no-op, and
/// the working copy on disk is unchanged.
class MediaStoreBackupSink implements BackupSink {
  @override
  Future<BackupCopy?> read() async {
    try {
      final raw = await recordBackupChannel.invokeMapMethod<Object?, Object?>(
        'read',
      );
      if (raw == null) return null;
      final vault = _bytes(raw['vault']);
      final manifest = raw['manifest'];
      if (vault == null || manifest is! String) return null;
      return BackupCopy(
        vault: vault,
        manifest: RecordManifest.tryParse(manifest),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> write(Uint8List vault, RecordManifest manifest) async {
    try {
      await recordBackupChannel.invokeMethod<void>('write', {
        'vault': vault,
        'manifest': manifest.encode(),
      });
    } on MissingPluginException {
      // No MediaStore on this desktop build.
    }
  }

  @override
  Future<void> delete() async {
    try {
      await recordBackupChannel.invokeMethod<void>('delete');
    } on MissingPluginException {
      // Same as write.
    }
  }

  Uint8List? _bytes(Object? value) {
    if (value is Uint8List) return value;
    if (value is List) return Uint8List.fromList(value.cast<int>());
    return null;
  }
}
