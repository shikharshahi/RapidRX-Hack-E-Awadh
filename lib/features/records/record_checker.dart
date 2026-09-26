import '../../core/dev_flags.dart';
import '../../core/storage/app_prefs.dart';
import 'demo_records.dart';
import 'record_ports.dart';
import 'secure_record_store.dart';

enum RecordPrompt { restore, demo, pin, locked, corrupt, done }

class RecordDecision {
  const RecordDecision(this.prompt, {this.manifest, this.preview});

  final RecordPrompt prompt;
  final RecordManifest? manifest;
  final DemoPreview? preview;
}

enum PinAttempt { ok, wrong, locked, rejected }

/// What the check screen should do after it has waited. No timers here.
class RecordChecker {
  RecordChecker({
    required this.prefs,
    this.maxTries = 5,
    this.lockFor = const Duration(minutes: 5),
    DateTime Function()? clock,
    SecureRecordStore? store,
  }) : _clock = clock ?? RecordHooks.clock ?? DateTime.now,
       _store = store;

  final AppPrefs prefs;
  final int maxTries;
  final Duration lockFor;
  final DateTime Function() _clock;
  SecureRecordStore? _store;

  DateTime get now => _clock();

  Future<SecureRecordStore> _open() async =>
      _store ??= await SecureRecordStore.open(clock: _clock);

  Future<RecordDecision> decide() async {
    final store = await _open();
    if (store.hasRecords && !DevFlags.demoRestore) {
      return const RecordDecision(RecordPrompt.done);
    }
    if (DevFlags.demoRestore && !prefs.demoUser) {
      return RecordDecision(
        RecordPrompt.demo,
        preview: DemoRecords.preview(now),
      );
    }
    if (store.hasRecords) return const RecordDecision(RecordPrompt.done);

    final copy = await store.backup.read();
    if (copy != null) {
      if (prefs.restoreDeclined) {
        return RecordDecision(
          store.fault == VaultFault.none
              ? RecordPrompt.done
              : RecordPrompt.corrupt,
        );
      }
      if (copy.manifest == null || !backupCanUnlock(copy.vault)) {
        return const RecordDecision(RecordPrompt.corrupt);
      }
      return RecordDecision(RecordPrompt.restore, manifest: copy.manifest);
    }
    if (store.fault != VaultFault.none) {
      return const RecordDecision(RecordPrompt.corrupt);
    }
    if (prefs.demoDeclined) return const RecordDecision(RecordPrompt.done);
    return RecordDecision(RecordPrompt.demo, preview: DemoRecords.preview(now));
  }

  bool get isLocked {
    final until = prefs.restoreLockedUntil;
    return until != null && now.isBefore(until);
  }

  Future<PinAttempt> enterPin(String pin) async {
    if (isLocked) return PinAttempt.locked;
    final until = prefs.restoreLockedUntil;
    if (until != null && !now.isBefore(until)) {
      await prefs.clearRestoreLock();
    }
    if (pin.length != 4) return PinAttempt.wrong;
    final store = await _open();
    switch (await store.restore(pin)) {
      case RestoreResult.ok:
        await prefs.clearRestoreLock();
        return PinAttempt.ok;
      case RestoreResult.wrongPin:
        final fails = prefs.restoreFails + 1;
        if (fails >= maxTries) {
          await prefs.lockRestoreUntil(now.add(lockFor));
          return PinAttempt.locked;
        }
        await prefs.setRestoreFails(fails);
        return PinAttempt.wrong;
      case RestoreResult.tampered:
      case RestoreResult.corrupt:
      case RestoreResult.nothing:
        return PinAttempt.rejected;
    }
  }

  Future<void> acceptDemo() async {
    final store = await _open();
    final existing = await store.backup.read();
    final mirror = store.mirrorBackup;
    if (existing != null) store.mirrorBackup = false;
    try {
      await DemoRecords.install(prefs: prefs, store: store, clock: _clock);
      await prefs.setDemoOwnsBackup(existing == null);
    } finally {
      store.mirrorBackup = mirror;
    }
  }

  Future<void> declineRestore() => prefs.setRestoreDeclined(true);

  Future<void> declineDemo() => prefs.setDemoDeclined(true);
}
