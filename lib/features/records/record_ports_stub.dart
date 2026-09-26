import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'record_ports.dart';

/// Web has no app-private file and no keystore.
///
/// The encrypted blob and its data key stay in memory for this tab.
/// ponytail: session memory. IndexedDB is the same two blobs behind
/// [RecordFile] and [KeyBox] if a refresh must keep them. Restore lookup
/// does not invent a file: [StubBackupSink.read] reports nothing found.
KeyBox createKeyBox() => MemoryKeyBox.shared;

RecordFile createRecordFile(SharedPreferences _) => _sessionFile;

final _sessionFile = MemoryRecordFile();

BackupSink createBackupSink() => StubBackupSink();

/// Nothing was found. The check screen can say so and offer the demo.
class StubBackupSink implements BackupSink {
  @override
  Future<BackupCopy?> read() async => null;

  @override
  Future<void> write(Uint8List vault, RecordManifest manifest) async {}

  @override
  Future<void> delete() async {}
}

/// Web is not the test runner. Keep the production round count.
int defaultKdfIterations() => 600000;
