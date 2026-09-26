import '../../core/storage/app_prefs.dart';
import '../pairing/pairing_code.dart';

/// What a PIN attempt did.
enum GateAttempt { opened, wrong, locked, noHash }

/// The paid caretaker's lock on the patient view.
///
/// The open flag lives on this object, so a new home (a fresh launch) asks
/// again. The failure count and the lock time are stored, so leaving the app
/// does not reset five wrong tries.
class ViewGate {
  ViewGate(this.prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const triesBeforeLock = 5;
  static const lockFor = Duration(minutes: 5);

  final AppPrefs prefs;
  final DateTime Function() _clock;

  bool _open = false;

  /// True after the right PIN in this visit to the home screen.
  bool get isOpen => !required || _open;

  bool get required => prefs.caretakerType == CaretakerType.commercial;

  bool get hasHash {
    final h = prefs.caretakerViewPinHash;
    return h != null && h.isNotEmpty;
  }

  DateTime? get lockedUntil {
    final ms = prefs.caretakerViewPinLockedUntil;
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  bool isLocked([DateTime? now]) {
    final until = lockedUntil;
    if (until == null) return false;
    return (now ?? _clock()).isBefore(until);
  }

  /// Whole minutes left, rounded up. Zero when the lock has passed.
  int minutesLeft([DateTime? now]) {
    final until = lockedUntil;
    final n = now ?? _clock();
    if (until == null || !n.isBefore(until)) return 0;
    final seconds = until.difference(n).inSeconds;
    final minutes = (seconds / 60).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  /// Store a hash found in a pasted WhatsApp message. False if there is none.
  Future<bool> acceptMessage(String raw) async {
    final hash = PairingCode.readConfirm(raw).pinHash;
    if (hash == null) return false;
    await prefs.setCaretakerViewPinHash(hash);
    return true;
  }

  Future<GateAttempt> submit(String pin) async {
    if (!required) {
      _open = true;
      return GateAttempt.opened;
    }
    final now = _clock();
    if (isLocked(now)) return GateAttempt.locked;
    if (!hasHash) return GateAttempt.noHash;
    final digits = pin.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(digits) ||
        prefs.caretakerViewPinHash != AppPrefs.hashPin(digits)) {
      return _wrong(now);
    }
    await prefs.setCaretakerViewPinFails(0);
    await prefs.setCaretakerViewPinLockedUntil(null);
    _open = true;
    return GateAttempt.opened;
  }

  Future<GateAttempt> _wrong(DateTime now) async {
    final fails = prefs.caretakerViewPinFails + 1;
    if (fails >= triesBeforeLock) {
      await prefs.setCaretakerViewPinFails(0);
      await prefs.setCaretakerViewPinLockedUntil(
        now.add(lockFor).millisecondsSinceEpoch,
      );
      return GateAttempt.locked;
    }
    await prefs.setCaretakerViewPinFails(fails);
    return GateAttempt.wrong;
  }
}
