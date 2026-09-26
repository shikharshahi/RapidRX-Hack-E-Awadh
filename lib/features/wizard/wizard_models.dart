import '../../domain/mention.dart';
import '../../domain/sig.dart';
import '../visit/visit.dart';

enum WizardStep {
  doctorWords,
  doctorTakeaways,
  photos,
  pharmacyWords,
  chemistTakeaways,
  processing,
  medicines,
  placement,
}

/// One row a person validates on the takeaways steps.
class Takeaway {
  Takeaway({
    required this.name,
    required this.sig,
    required this.sourceText,
    required this.ticked,
    required this.clear,
    this.isNote = false,
  });

  factory Takeaway.note(String text) => Takeaway(
    name: text,
    sig: Sig.empty,
    sourceText: '',
    ticked: false,
    clear: true,
    isNote: true,
  );

  /// As it was said — "Telma 40".
  String name;
  Sig sig;

  /// What goes to the analyser. The original words until a person edits the
  /// row; after that, the name and the edited instruction.
  String sourceText;
  bool ticked;

  /// Parsed with nothing left over, and with a time.
  bool clear;

  /// Advice, not a medicine. Kept visible; never becomes a dose.
  final bool isNote;

  /// The raw instruction when the parser could not make sense of it, so the
  /// row shows the words themselves rather than a confident guess.
  String? rawInstruction;
}

/// A photo in the photo step, before it becomes part of the visit.
class PhotoCandidate {
  PhotoCandidate({
    required this.path,
    required this.label,
    this.selected = true,
    this.ocrText,
    this.evidence = const [],
    this.reason,
  });

  final String path;
  PhotoLabel label;

  /// Only ticked photos enter the visit, and only when the step is left.
  bool selected;

  /// Read once, and reused by extraction.
  String? ocrText;
  bool reading = false;
  bool unreadable = false;

  /// The words that decided the label — shown, so the label can be checked.
  List<String> evidence;

  /// Why it was turned away, when it was.
  String? reason;
}

/// What a person decided about one medicine card.
class MedicineDecision {
  bool confirmed = false;
  bool leftOut = false;

  /// On a red card, the side the person picked.
  Mention? chosen;

  /// A person's own fix, which beats every source.
  String? editedName;
  Sig? editedSig;

  bool get decided => confirmed || leftOut;
}
