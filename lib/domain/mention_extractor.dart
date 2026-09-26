import 'mention.dart';
import 'sig.dart';
import 'sig_parser.dart';

/// Turns one source's text into mentions of medicines.
///
/// Photos arrive as OCR lines; speech arrives as one run-on sentence. Both are
/// cut into segments, and each segment is either a new medicine (it has a
/// name that looks like one) or more instruction for the medicine before it —
/// a handwritten prescription usually puts "1-0-1 x 5 days" on the next line.
abstract final class MentionExtractor {
  static List<Mention> extract(String text, SourceKind source) {
    final segments = _segments(text, speech: _isSpeech(source));
    final out = <Mention>[];
    Mention? current;

    for (final seg in segments) {
      final line = SigParser.parseLine(seg);
      if (line.name != null) {
        final evidence = _hasEvidence(line);
        if (evidence || _isSpeech(source)) {
          if (current != null) out.add(current);
          current = Mention(
            source: source,
            name: line.name!,
            strength: line.strength,
            sig: line.sig,
            raw: seg.trim(),
            purpose: line.purpose,
            needsCorroboration: !evidence,
          );
          continue;
        }
      }

      // No name: instruction for the medicine above, if it carries any.
      final sig = SigParser.parseSig(seg);
      final carries =
          sig.hasTiming ||
          sig.food != FoodTiming.unspecified ||
          sig.durationDays != null ||
          sig.everyNDays != null;
      if (current != null && (carries || line.purpose != null)) {
        current = current.copyWith(
          sig: _combine(current.sig, sig),
          raw: '${current.raw}  ${seg.trim()}',
          purpose: current.purpose ?? line.purpose,
          // "Telma, subah ek": the instruction that follows is the evidence.
          needsCorroboration: current.needsCorroboration && !carries,
        );
      }
    }
    if (current != null) out.add(current);
    return out;
  }

  static bool _isSpeech(SourceKind s) =>
      s == SourceKind.doctor || s == SourceKind.chemist;

  /// Photos: one segment per line. Speech: also split at pauses and at "and
  /// then", because a dictated visit is one long sentence.
  static List<String> _segments(String text, {required bool speech}) {
    var lines = text.split(RegExp(r'[\r\n]+'));
    if (speech) {
      lines = [
        for (final l in lines)
          ...l.split(
            RegExp(
              r'[.;।]|,(?!\s*\d)|\b(?:and then|aur phir|aur fir|then|phir|uske baad)\b',
              caseSensitive: false,
            ),
          ),
      ];
    }
    return [
      for (final l in lines)
        if (l.trim().isNotEmpty) l.trim(),
    ];
  }

  /// A name alone is not enough: "Dr Sharma" and "Patient Ramesh" have names.
  /// A medicine line has a dosage form, a strength, or an instruction.
  static bool _hasEvidence(ParsedLine line) =>
      line.form != null ||
      line.strength != null ||
      line.sig.hasTiming ||
      line.sig.food != FoodTiming.unspecified ||
      line.sig.durationDays != null;

  static Sig _combine(Sig a, Sig b) => a.fillFrom(b);
}
