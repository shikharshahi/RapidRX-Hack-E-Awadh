import 'app_strings.dart';

/// The record check, before a language has been chosen. The screen shows the
/// English and the Hindi of each line together; [pick] is what a later screen
/// uses once a language exists.
extension RecordStrings on AppStrings {
  String get recordChecking => pick(
    'Checking for your medical records…',
    'आपकी मेडिकल फ़ाइलें खोजी जा रही हैं…',
  );

  String get recordRestoreQuestion => pick(
    'Previous medical files found. Restore and sync them?',
    'पहले की मेडिकल फ़ाइलें मिलीं। उन्हें वापस लाकर सिंक करें?',
  );

  String recordSummary({
    required String date,
    required int medicines,
    required int prescriptions,
    required int doses,
  }) => pick(
    '$date · $medicines medicines · $prescriptions prescriptions · $doses doses',
    '$date · $medicines दवाइयाँ · $prescriptions पर्चियाँ · $doses खुराक',
  );

  String get recordDemoQuestion => pick(
    'No saved medical files on this phone. Load the demo user?',
    'इस फ़ोन पर कोई सेव मेडिकल फ़ाइल नहीं मिली। डेमो उपयोगकर्ता खोलें?',
  );

  String get recordYes => 'Yes · हाँ';
  String get recordNo => 'No · नहीं';

  String get recordPinTitle => pick(
    'Enter the 4-digit PIN for these files',
    'इन फ़ाइलों का 4 अंकों का PIN डालें',
  );

  String get recordPinWrong =>
      pick('That PIN does not open the files.', 'यह PIN फ़ाइलें नहीं खोलता।');

  String recordPinLocked(int minutes) => pick(
    'Too many tries. Wait $minutes minutes, then try again.',
    'बहुत बार गलत हुआ। $minutes मिनट रुकें, फिर कोशिश करें।',
  );

  String get recordNotNow => 'Not now · अभी नहीं';

  String get recordCorrupt => pick(
    'This file could not be read. It was left as it is.',
    'यह फ़ाइल पढ़ी नहीं जा सकी। इसे जस का तस रखा गया है।',
  );

  String get recordContinue => 'Continue · आगे बढ़ें';

  String get recordDemoUser => pick('Demo user', 'डेमो उपयोगकर्ता');

  String get recordLeaveDemo => pick('Leave demo', 'डेमो छोड़ें');
}
