import 'app_language.dart';

/// Every word the app shows, in both languages, as a typed Dart table.
///
/// Not intl, not ARB: two languages, one team, one weekend. A getter per string
/// means a missing translation is a compile error rather than a blank label on
/// a demo phone, and a reviewer can read the English and the Hindi side by side.
///
/// Medicine names are never in this table. They stay in English letters exactly
/// as printed — in the Hindi UI too — because the patient has to match them
/// against the pack in their hand.
class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  bool get isHindi => language == AppLanguage.hi;

  String _t(String en, String hi) => isHindi ? hi : en;

  // ── Brand ────────────────────────────────────────────────────────────────
  String get appName => 'RapidRX';
  String get tagline => _t('Every dose, on time', 'हर दवाई, सही समय');

  // ── Language (the one screen that is bilingual at once) ─────────────────
  static const languageQuestionEn = 'Which language are you comfortable in?';
  static const languageQuestionHi = 'आप किस भाषा में सहज हैं?';
  static const englishOption = 'ENGLISH';
  static const hindiOption = 'हिंदी';

  String get savingPreference =>
      _t('Saving your preference…', 'आपकी पसंद सेव हो रही है…');

  // ── Voice help ──────────────────────────────────────────────────────────
  String get voiceQuestion =>
      _t('Do you need voice help?', 'क्या आपको आवाज़ में मदद चाहिए?');
  String get voiceWhy => _t(
    'RapidRX will read each screen aloud, and repeat it every little while. '
        'It works without internet too.',
    'RapidRX हर स्क्रीन पढ़कर सुनाएगा, और थोड़ी-थोड़ी देर में दोहराएगा। '
        'यह बिना इंटरनेट के भी काम करता है।',
  );
  String get yes => _t('Yes', 'हाँ');
  String get no => _t('No', 'नहीं');

  // ── Phone and OTP ───────────────────────────────────────────────────────
  String get phoneTitle => _t('Your mobile number', 'आपका मोबाइल नंबर');
  String get phoneWhy => _t(
    'Used to link your family member’s phone later. '
        'No SMS is sent in this demo.',
    'बाद में आपके परिवार के सदस्य का फ़ोन जोड़ने के लिए। '
        'इस डेमो में कोई SMS नहीं भेजा जाता।',
  );
  String get phoneHint => _t('Mobile number', 'मोबाइल नंबर');
  String get phoneInvalid =>
      _t('Enter a 10-digit mobile number', '10 अंकों का मोबाइल नंबर लिखें');

  String get otpTitle => _t('Enter the code', 'कोड लिखें');
  String otpSentTo(String phone) => _t(
    'We sent a 4-digit code to +91 $phone',
    'हमने +91 $phone पर 4 अंकों का कोड भेजा है',
  );
  String get otpHint => _t('4-digit code', '4 अंकों का कोड');
  String get otpWrong => _t(
    'That code is not right. Try again.',
    'यह कोड सही नहीं है। फिर से लिखें।',
  );
  String get otpDemoHint =>
      _t('Demo build: the code is 1234', 'डेमो: कोड 1234 है');
  String get verify => _t('Verify', 'जाँचें');

  // ── Profile ─────────────────────────────────────────────────────────────
  String get profileTitle => _t('About you', 'आपके बारे में');
  String get nameHint => _t('Your name', 'आपका नाम');
  String get nameMissing =>
      _t('Please write your name', 'कृपया अपना नाम लिखें');
  String get backupLabel =>
      _t('Family member’s number', 'परिवार के सदस्य का नंबर');
  String get optional => _t('Optional', 'ज़रूरी नहीं');
  String get backupWhy => _t(
    'If you add one, we will check it too. You can add it later.',
    'अगर आप जोड़ते हैं तो हम उसे भी जाँचेंगे। आप इसे बाद में भी जोड़ सकते हैं।',
  );
  String get backupOtpTitle =>
      _t('Code for your family member', 'परिवार के सदस्य का कोड');

  // ── PIN ─────────────────────────────────────────────────────────────────
  String get pinTitle => _t('Set a 4-digit PIN', '4 अंकों का PIN बनाएँ');
  String get pinWhy => _t(
    'You will use it to open RapidRX. Choose something you will remember.',
    'इससे आप RapidRX खोलेंगे। ऐसा चुनें जो आपको याद रहे।',
  );
  String get pinConfirmTitle => _t('Enter the PIN again', 'PIN फिर से लिखें');
  String get pinConfirmWhy =>
      _t('To make sure it is right.', 'ताकि पक्का हो जाए कि यह सही है।');
  String get pinInvalid =>
      _t('The PIN must be 4 digits', 'PIN 4 अंकों का होना चाहिए');
  String get pinMismatch => _t(
    'The two PINs are different. Set it again.',
    'दोनों PIN अलग हैं। फिर से बनाएँ।',
  );

  // ── Role ────────────────────────────────────────────────────────────────
  String get roleQuestion =>
      _t('Who is using this app?', 'यह ऐप कौन चला रहा है?');
  String get patient => _t('PATIENT', 'मरीज़');
  String get patientWhy =>
      _t('I want to track my prescription', 'मुझे अपनी दवाई पर नज़र रखनी है');
  String get caregiver => _t('CAREGIVER', 'देखभाल करने वाला');
  String get caregiverWhy => _t(
    'I want to help a patient track their prescription',
    'मुझे किसी की दवाई का ध्यान रखना है',
  );

  // ── Patient menu ────────────────────────────────────────────────────────
  String get menuTitle => _t('Today\'s medicines', 'आज की दवाई');
  String get menuQuestion =>
      _t('What would you like to do?', 'आप क्या करना चाहते हैं?');
  String get newPrescription => _t('New prescription', 'नई पर्ची');
  String get newPrescriptionWhy => _t(
    'Photograph a prescription, bill or strip',
    'पर्ची, बिल या दवाई के पत्ते की फ़ोटो लें',
  );
  String get myPrescriptions => _t('My prescriptions', 'मेरी पर्चियाँ');
  String get myPrescriptionsWhy =>
      _t('Everything added so far', 'अब तक जोड़ी गई सब पर्चियाँ');
  String get medicineSchedule => _t('Medicine schedule', 'दवाई का समय');
  String get medicineScheduleWhy =>
      _t('What to take today, and when', 'आज क्या और कब लेना है');
  String get noPrescriptionsYet => _t(
    'No prescriptions yet. Add one to build your daily plan.',
    'अभी कोई पर्ची नहीं है। एक जोड़िए, फिर रोज़ का प्लान बनेगा।',
  );

  // ── App bar actions ─────────────────────────────────────────────────────
  String get voiceOn => _t('Voice help is on', 'आवाज़ में मदद चालू है');
  String get voiceOff => _t('Voice help is off', 'आवाज़ में मदद बंद है');
  String get switchLanguage => _t('हिंदी में देखें', 'Switch to English');
  String get account => _t('Account', 'खाता');
  String get changeRole =>
      _t('Change who is using the app', 'ऐप चलाने वाला बदलें');
  String get startAgain =>
      _t('Start again from the beginning', 'शुरू से फिर करें');
  String get startAgainWhy => _t(
    'Your name, number and PIN will be asked again.',
    'आपका नाम, नंबर और PIN फिर से पूछा जाएगा।',
  );

  // ── Shared ──────────────────────────────────────────────────────────────
  String get continueLabel => _t('Continue', 'आगे बढ़ें');
  String get back => _t('Back', 'पीछे');
  String get next => _t('Next', 'आगे');
  String get skip => _t('Skip', 'छोड़ें');
  String get cancel => _t('Cancel', 'रद्द करें');
  String get done => _t('Done', 'हो गया');
  String get save => _t('Save', 'सेव करें');
  String get change => _t('Change', 'बदलें');
}
