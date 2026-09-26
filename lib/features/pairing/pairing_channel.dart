import 'package:flutter/foundation.dart';

import 'pairing_code.dart';

/// What happened when a caretaker typed the patient's code.
enum ConfirmOutcome {
  /// The code matches: the two phones saw the same QR code.
  linked,

  /// Not the code the patient's phone shows.
  wrongCode,
}

/// The check, plus the commercial PIN hash when this confirm carried one.
class ConfirmResult {
  const ConfirmResult(this.outcome, {this.pinHash});

  final ConfirmOutcome outcome;

  /// SHA-256 of the PIN the patient set, or null for a family link.
  final String? pinHash;

  bool get linked => outcome == ConfirmOutcome.linked;
}

/// How the two phones agree that a pairing happened.
///
/// There is no backend in this build (ADR-45). A real one replaces
/// [LocalPairingChannel] behind this interface: the patient's phone posts the
/// link, and the caretaker's phone is told — no code to type. Until then the
/// patient's phone shows a 4-digit code and the caretaker types it, which
/// proves the patient really scanned *this* caretaker's QR.
abstract class PairingChannel {
  /// Patient phone: the patient accepted [caretaker]. Returns the 4-digit
  /// code to show the caretaker. [pinHash] is set for a paid caretaker.
  Future<String> patientLinked(
    PairingPayload caretaker, {
    required String patientName,
    String? pinHash,
  });

  /// Caretaker phone: check the code the patient's phone shows.
  /// [code] may be the 4 digits, or the whole WhatsApp message.
  Future<ConfirmResult> caretakerConfirm({
    required String caretakerId,
    required String code,
  });
}

/// No network: both phones derive the code from the caretaker id.
class LocalPairingChannel implements PairingChannel {
  const LocalPairingChannel();

  /// ponytail: one map in this process. Two phones do not share it; the
  /// `RXPIN` line in the WhatsApp message is that copy. A backend replaces both.
  static final Map<String, String> _pins = {};

  @visibleForTesting
  static void debugForgetPins() => _pins.clear();

  @override
  Future<String> patientLinked(
    PairingPayload caretaker, {
    required String patientName,
    String? pinHash,
  }) async {
    if (pinHash != null && pinHash.isNotEmpty) {
      _pins[caretaker.caretakerId] = pinHash;
    }
    return PairingCode.confirmationCode(caretaker.caretakerId);
  }

  @override
  Future<ConfirmResult> caretakerConfirm({
    required String caretakerId,
    required String code,
  }) async {
    final read = PairingCode.readConfirm(code);
    if (read.code != PairingCode.confirmationCode(caretakerId)) {
      return const ConfirmResult(ConfirmOutcome.wrongCode);
    }
    return ConfirmResult(
      ConfirmOutcome.linked,
      pinHash: read.pinHash ?? _pins[caretakerId],
    );
  }
}
