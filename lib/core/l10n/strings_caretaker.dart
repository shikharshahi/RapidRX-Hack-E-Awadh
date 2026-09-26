import '../storage/app_prefs.dart' show CaretakerType;
import 'app_strings.dart';

/// Caretaker onboarding, pairing, the patient's scan, and the caretaker home
/// by type. Same rule as AppStrings: English and Hindi side by side.
extension CaretakerStrings on AppStrings {
  // ── Who are you to the patient? ─────────────────────────────────────────
  String get caretakerTypeQuestion =>
      pick('Who are you to the patient?', 'आप मरीज़ के कौन हैं?');
  String get caretakerTypeWhy => pick(
    'This decides what you can see.',
    'इससे तय होता है कि आप क्या देख पाएँगे।',
  );
  String get familyMember => pick('Family member', 'परिवार का सदस्य');
  String get familyMemberWhy => pick(
    'Son, daughter, spouse or relative. You see everything.',
    'बेटा, बेटी, पति-पत्नी या रिश्तेदार। आप सब कुछ देख पाएँगे।',
  );
  String get commercialCaretaker =>
      pick('Non-family caretaker', 'परिवार से बाहर के देखभालकर्ता');
  String get commercialCaretakerWhy => pick(
    'A paid attendant or nurse. The patient sets a PIN, and you see '
        'the doses and notes.',
    'पैसे लेकर देखभाल करने वाले या नर्स। मरीज़ एक PIN रखेंगे, और आप '
        'दवाई और नोट देख पाएँगे।',
  );
  String caretakerTypeLabel(CaretakerType t) => switch (t) {
    CaretakerType.family => familyMember,
    CaretakerType.commercial => commercialCaretaker,
  };

  // ── Your QR code ────────────────────────────────────────────────────────
  String get pairingQrTitle =>
      pick('Your caretaker QR code', 'आपका देखभालकर्ता QR कोड');
  String get pairingQrWhy => pick(
    'Ask the patient to open RapidRX and tap "Scan caretaker QR".',
    'मरीज़ से कहें: RapidRX खोलें, फिर "देखभालकर्ता का QR स्कैन करें" दबाएँ।',
  );
  String pairingValidFor(int minutes) => pick(
    minutes == 1
        ? 'Works for 1 more minute'
        : 'Works for $minutes more minutes',
    'अभी $minutes मिनट और चलेगा',
  );
  String get pairingExpired => pick(
    'This code has expired. Make a new one.',
    'इस कोड का समय खत्म हो गया। नया बनाएँ।',
  );
  String get makeNewCode => pick('Make a new code', 'नया कोड बनाएँ');
  String get orTypeThisCode => pick(
    'No camera? Send this code to the patient to type or paste:',
    'कैमरा नहीं है? यह कोड मरीज़ को भेजें, वे इसे लिख या पेस्ट कर सकते हैं:',
  );
  String get shareCode => pick('Send the code', 'कोड भेजें');
  String get enterPatientCode =>
      pick('Enter the patient\'s code', 'मरीज़ का कोड डालें');
  String get doThisLater => pick('I\'ll do this later', 'यह बाद में करूँगा');
  String get pairingDemoHint => pick(
    'Demo: there is no server. After scanning, the patient\'s phone shows a '
        '4-digit code that completes the link.',
    'डेमो: कोई सर्वर नहीं है। स्कैन के बाद मरीज़ के फ़ोन पर 4 अंकों का '
        'कोड आता है, उसी से जुड़ाव पूरा होता है।',
  );

  // ── Enter the patient's code ────────────────────────────────────────────
  String get confirmWhy => pick(
    'After the patient scans your QR code, their phone shows their name and '
        'a 4-digit code.',
    'मरीज़ के आपका QR कोड स्कैन करने के बाद, उनके फ़ोन पर उनका नाम और '
        '4 अंकों का कोड दिखेगा।',
  );
  String get patientNameHint => pick('Patient\'s name', 'मरीज़ का नाम');
  String get fourDigitCode => pick('4-digit code', '4 अंकों का कोड');
  String get connect => pick('Connect', 'जोड़ें');
  String get patientNameMissing =>
      pick('Write the patient\'s name', 'मरीज़ का नाम लिखें');
  String get codeShort => pick('The code has 4 digits', 'कोड 4 अंकों का है');
  String get codeWrong => pick(
    'That code does not match. Check the patient\'s phone.',
    'यह कोड मेल नहीं खाता। मरीज़ का फ़ोन देखें।',
  );
  String get connectionSuccessful =>
      pick('Caretaker connection successful', 'देखभालकर्ता जुड़ गए');
  String linkedTo(String name) =>
      pick('You are now linked to $name.', 'अब आप $name से जुड़ गए हैं।');
  String get ok => pick('OK', 'ठीक है');

  // ── Caretaker home: the link ────────────────────────────────────────────
  String get notLinkedYet =>
      pick('Not linked to a patient yet.', 'अभी किसी मरीज़ से नहीं जुड़े हैं।');
  String get showMyQr => pick('Show my QR code', 'मेरा QR कोड दिखाएँ');
  String linkedPatientLine(String name) =>
      pick('Linked to $name', '$name से जुड़े हैं');
}
