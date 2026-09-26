import 'app_strings.dart';

/// Shown while raw conversations are deleted after a prescription is saved.
extension WipeStrings on AppStrings {
  String get wipeLine => pick(
    'Conversations deleted. Your prescription is saved encrypted on this phone only.',
    'बातचीत हटा दी गई। आपकी पर्ची सिर्फ़ इस फ़ोन पर एन्क्रिप्टेड सेव है।',
  );
}
