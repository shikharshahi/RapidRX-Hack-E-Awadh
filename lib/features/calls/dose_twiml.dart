import '../../core/l10n/app_language.dart';

/// TwiML for one missed-dose call. No network.
///
/// The spoken line is the medicine name and the three keys. A transcript or
/// a note cannot be passed in: this function has nowhere to put one.
///
/// ponytail: `<Say>` until a public Kokoro clip exists; then `<Play>` that
/// clip instead of the intro `<Say>`. The name still must not become a note.
String buildDoseTwiml({
  required AppLanguage language,
  required List<String> medicineNames,
  required String gatherUrl,
}) {
  final names = [
    for (final n in medicineNames)
      if (n.trim().isNotEmpty) n.trim(),
  ].join(', ');
  final lang = language.locale;
  final intro = language == AppLanguage.hi
      ? 'नमस्ते। RapidRX से, यह एक ऑटोमैटिक कॉल है। आपकी दवाई: $names।'
      : 'Hello. This is an automatic call from RapidRX. Your medicine: $names.';
  final ask = language == AppLanguage.hi
      ? 'ले ली है तो 1 दबाइए। अभी नहीं तो 2। परिवार को बताना है तो 9।'
      : 'Press 1 if taken. Press 2 for later. Press 9 to tell your family.';
  return '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<Response>\n'
      '  <Say language="$lang">${_xml(intro)}</Say>\n'
      '  <Gather numDigits="1" timeout="8" action="${_xml(gatherUrl)}" method="POST">\n'
      '    <Say language="$lang">${_xml(ask)}</Say>\n'
      '  </Gather>\n'
      '</Response>\n';
}

String _xml(String raw) => raw
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
