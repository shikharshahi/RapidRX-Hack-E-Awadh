import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'record_ports_stub.dart'
    if (dart.library.io) 'record_ports_io.dart'
    as ports;

/// Where the day-to-day data key lives.
///
/// Android uses the keystore ([ports]). Tests and the web stub inject a
/// [MemoryKeyBox] so nothing here needs a real keystore.
abstract class KeyBox {
  Future<Uint8List?> read();
  Future<void> write(Uint8List key);
  Future<void> delete();
}

/// In-memory key. Shared by the test runner; a unit test can keep its own.
class MemoryKeyBox implements KeyBox {
  MemoryKeyBox();

  static final shared = MemoryKeyBox();

  Uint8List? value;

  @override
  Future<Uint8List?> read() async => value;

  @override
  Future<void> write(Uint8List key) async => value = Uint8List.fromList(key);

  @override
  Future<void> delete() async => value = null;
}

/// The encrypted working copy. One blob, replaced on every write.
abstract class RecordFile {
  Future<Uint8List?> read();
  Future<void> write(Uint8List bytes);
  Future<void> delete();
}

class MemoryRecordFile implements RecordFile {
  Uint8List? value;

  @override
  Future<Uint8List?> read() async => value;

  @override
  Future<void> write(Uint8List bytes) async =>
      value = Uint8List.fromList(bytes);

  @override
  Future<void> delete() async => value = null;
}

/// A found backup: the encrypted vault, and the plain manifest beside it.
class BackupCopy {
  const BackupCopy({required this.vault, required this.manifest});

  final Uint8List vault;

  /// Null when the manifest bytes are not the plain JSON we write.
  final RecordManifest? manifest;
}

/// Mirrored after every change that actually holds medical records.
///
/// Android 10+ writes Documents/RapidRX through MediaStore. Tests use
/// [MemoryBackupSink], which only records the bytes.
abstract class BackupSink {
  Future<BackupCopy?> read();
  Future<void> write(Uint8List vault, RecordManifest manifest);
  Future<void> delete();
}

/// Records the last bytes it was given. Nothing is deleted unless [delete]
/// is called — "No" on the restore question must leave the file.
class MemoryBackupSink implements BackupSink {
  Uint8List? vault;
  String? manifestJson;

  @override
  Future<BackupCopy?> read() async {
    final bytes = vault;
    if (bytes == null) return null;
    return BackupCopy(
      vault: bytes,
      manifest: manifestJson == null
          ? null
          : RecordManifest.tryParse(manifestJson!),
    );
  }

  @override
  Future<void> write(Uint8List vault, RecordManifest manifest) async {
    this.vault = Uint8List.fromList(vault);
    manifestJson = manifest.encode();
  }

  @override
  Future<void> delete() async {
    vault = null;
    manifestJson = null;
  }
}

KeyBox createKeyBox() => ports.createKeyBox();

RecordFile createRecordFile(dynamic prefs) => ports.createRecordFile(prefs);

BackupSink createBackupSink() => ports.createBackupSink();

/// PBKDF2 rounds for a new wrap.
///
/// Production stays high. The test runner (see the io factory) uses a much
/// smaller count so a PIN set during `flutter test` stays fast. A backup
/// stores the count it was wrapped with, and restore uses that stored count.
int defaultKdfIterations() => ports.defaultKdfIterations();

/// Plain file beside the vault. Counts and a phone hash — never a medicine,
/// a dose, or a name.
class RecordManifest {
  const RecordManifest({
    required this.createdAt,
    required this.updatedAt,
    required this.counts,
    this.phoneHash,
  });

  static const version = 1;

  final String createdAt;
  final String updatedAt;

  /// medicines, prescriptions, doseLogs, visits.
  final Map<String, int> counts;
  final String? phoneHash;

  int count(String key) => counts[key] ?? 0;

  String encode() => jsonEncode({
    'v': version,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'counts': counts,
    if (phoneHash != null) 'phoneHash': phoneHash,
  });

  static RecordManifest? tryParse(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      if (j['v'] != version) return null;
      final created = j['createdAt'];
      final updated = j['updatedAt'];
      final counts = j['counts'];
      if (created is! String || updated is! String || counts is! Map) {
        return null;
      }
      final parsed = <String, int>{};
      for (final e in counts.entries) {
        if (e.key is! String || e.value is! int) return null;
        parsed[e.key as String] = e.value as int;
      }
      final phone = j['phoneHash'];
      if (phone != null && phone is! String) return null;
      return RecordManifest(
        createdAt: created,
        updatedAt: updated,
        counts: parsed,
        phoneHash: phone as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Overridden by tests that drive [SecureRecordStore.open] through the app.
/// Production leaves every field null.
abstract final class RecordHooks {
  static int? kdfIterations;
  static DateTime Function()? clock;
  static BackupSink? backup;
  static KeyBox? keyBox;
  static RecordFile? file;

  static void reset() {
    kdfIterations = null;
    clock = null;
    backup = null;
    keyBox = null;
    file = null;
  }
}

/// The Android channel. Missing on Windows, Linux and tests — the caller
/// treats that as "nothing found", and does not pretend a file was written.
const recordBackupChannel = MethodChannel('rapidrx/record_backup');
