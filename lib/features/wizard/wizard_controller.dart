import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';

import '../../domain/content_gate.dart';
import '../../domain/mention.dart';
import '../../domain/mention_extractor.dart';
import '../../domain/merge_engine.dart';
import '../../domain/offline_analyser.dart';
import '../../domain/placement_advisor.dart';
import '../../domain/scheduled_medicine.dart';
import '../../domain/sig.dart';
import '../../domain/sig_parser.dart';
import '../../platform/text_recogniser.dart';
import '../medicines/medicine_store.dart';
import '../visit/media_store.dart';
import '../visit/visit.dart';
import '../visit/visit_repository.dart';
import 'wizard_models.dart';

/// Everything the eight-step "new prescription" wizard knows and decides,
/// with no widgets in it — so every step can be driven by a test, and the
/// goldens show what the real controller produced rather than a mock-up.
class VisitWizardController extends ChangeNotifier {
  VisitWizardController({
    required this.visit,
    required this.repository,
    required this.store,
    MediaStore? media,
    TextRecogniser? recogniser,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _media = media;
    _recogniser = recogniser;
  }

  final Visit visit;
  final VisitRepository repository;
  final MedicineStore store;
  final DateTime Function() _clock;

  // Built lazily: both touch the platform.
  MediaStore? _media;
  MediaStore get media => _media ??= MediaStore();
  TextRecogniser? _recogniser;
  TextRecogniser get recogniser => _recogniser ??= TextRecogniser();

  WizardStep _step = WizardStep.doctorWords;
  WizardStep get step => _step;
  int get stepNumber => _step.index + 1;
  static int get stepCount => WizardStep.values.length;

  // ── Navigation ──────────────────────────────────────────────────────────

  bool get canGoBack => _step.index > 0;

  /// Why Next is locked, or null when it is not.
  bool get canGoNext => switch (_step) {
    WizardStep.photos => photosReady,
    WizardStep.processing => analysis != null && !_analysing,
    WizardStep.medicines => allDecided && keptRows.isNotEmpty,
    WizardStep.placement => placements.isNotEmpty,
    _ => true,
  };

  /// Honest only where the step really is optional.
  bool get canSkip => switch (_step) {
    WizardStep.doctorWords || WizardStep.pharmacyWords => true,
    WizardStep.doctorTakeaways || WizardStep.chemistTakeaways => true,
    _ => false,
  };

  Future<void> next() async {
    if (!canGoNext || _step == WizardStep.placement) return;
    await _leave(_step);
    _step = WizardStep.values[_step.index + 1];
    await _enter(_step);
    notifyListeners();
  }

  Future<void> skip() async {
    if (!canSkip) return;
    // A skipped step is recorded as "not provided": never blank, never
    // guessed.
    if (!visit.notProvided.contains(_step.name)) {
      visit.notProvided.add(_step.name);
    }
    if (_step == WizardStep.doctorWords) {
      visit.notProvided.add(WizardStep.doctorTakeaways.name);
    } else if (_step == WizardStep.pharmacyWords) {
      visit.notProvided.add(WizardStep.chemistTakeaways.name);
    }
    // Skipping the words skips their checkpoint as well.
    if (_step == WizardStep.doctorWords) {
      _step = WizardStep.photos;
    } else if (_step == WizardStep.pharmacyWords) {
      _step = WizardStep.processing;
      await _enter(_step);
    } else {
      await _leave(_step);
      _step = WizardStep.values[_step.index + 1];
      await _enter(_step);
    }
    notifyListeners();
  }

  void back() {
    if (!canGoBack) return;
    _step = WizardStep.values[_step.index - 1];
    notifyListeners();
  }

  Future<void> _enter(WizardStep s) async {
    switch (s) {
      case WizardStep.doctorTakeaways:
        _refreshTakeaways(SourceKind.doctor);
      case WizardStep.chemistTakeaways:
        _refreshTakeaways(SourceKind.chemist);
      case WizardStep.processing:
        await runAnalysis();
      case WizardStep.placement:
        _placeMedicines();
      default:
    }
  }

  Future<void> _leave(WizardStep s) async {
    if (s == WizardStep.photos) await commitPhotos();
    await repository.save(visit);
  }

  // ── Steps 1 and 4: words ────────────────────────────────────────────────

  void setWords(SourceKind who, String text) {
    if (who == SourceKind.doctor) {
      visit.doctorWords = text;
    } else {
      visit.chemistWords = text;
    }
    repository.save(visit);
    notifyListeners();
  }

  String wordsOf(SourceKind who) =>
      who == SourceKind.doctor ? visit.doctorWords : visit.chemistWords;

  Future<void> keepAudio(SourceKind who, XFile file) async {
    final name = who == SourceKind.doctor ? 'doctor' : 'chemist';
    final path = await media.keep(visit.id, file, name: name);
    if (who == SourceKind.doctor) {
      visit.doctorAudioPath = path;
    } else {
      visit.chemistAudioPath = path;
    }
    await repository.save(visit);
    notifyListeners();
  }

  /// Forget a kept recording: deleted, or about to be recorded again.
  Future<void> dropAudio(SourceKind who) async {
    if (who == SourceKind.doctor) {
      visit.doctorAudioPath = null;
    } else {
      visit.chemistAudioPath = null;
    }
    await repository.save(visit);
    notifyListeners();
  }

  // ── Steps 2 and 5: takeaways ────────────────────────────────────────────

  final Map<SourceKind, List<Takeaway>> _takeaways = {};
  final Map<SourceKind, String> _takeawaysFrom = {};

  List<Takeaway> takeaways(SourceKind who) => _takeaways[who] ?? const [];

  /// Rebuilt only when the words changed, so a person's ticks and edits
  /// survive going back a step and forward again.
  void _refreshTakeaways(SourceKind who) {
    final words = wordsOf(who);
    if (_takeawaysFrom[who] == words && _takeaways.containsKey(who)) return;
    _takeawaysFrom[who] = words;
    final x = MentionExtractor.extractWithNotes(words, who);
    _takeaways[who] = [
      for (final m in x.mentions) _takeawayOf(m),
      for (final n in x.notes) Takeaway.note(n),
    ];
  }

  static Takeaway _takeawayOf(Mention m) {
    final clear = m.sig.isClear && m.sig.hasTiming && !m.needsCorroboration;
    final t = Takeaway(
      name: _asSaid(m),
      sig: m.sig,
      sourceText: m.raw,
      ticked: clear,
      clear: clear,
      purpose: m.purpose,
    );
    if (!m.sig.isClear || !m.sig.hasTiming) {
      // Show the words themselves, not a confident reading of them.
      final rest = SigParser.normalise(m.raw)
          .replaceFirst(SigParser.normalise(m.name), '');
      t.rawInstruction = rest.trim().isEmpty ? null : _sentence(rest.trim());
    }
    return t;
  }

  static String _asSaid(Mention m) => m.name
      .split(' ')
      .map(
        (w) => RegExp(r'^\d').hasMatch(w) || w.length <= 2
            ? w
            : w[0] + w.substring(1).toLowerCase(),
      )
      .join(' ');

  static String _sentence(String s) => s[0].toUpperCase() + s.substring(1);

  void toggleTakeaway(SourceKind who, int i) {
    final t = _takeaways[who]![i];
    t.ticked = !t.ticked;
    notifyListeners();
  }

  /// A person's fix. The row is then clear by definition: a human wrote it.
  void editTakeaway(SourceKind who, int i, String name, String instruction) {
    final t = _takeaways[who]![i];
    final line = '$name $instruction'.trim();
    final parsed = SigParser.parseLine(line);
    t
      ..name = name.trim()
      ..sig = parsed.sig
      ..sourceText = line
      ..rawInstruction = parsed.sig.isClear ? null : instruction.trim()
      ..clear = parsed.sig.isClear && parsed.sig.hasTiming
      ..ticked = true;
    notifyListeners();
  }

  void addTakeaway(SourceKind who, String name, String instruction) {
    _takeaways.putIfAbsent(who, () => []);
    _takeaways[who]!.add(
      Takeaway(
        name: name,
        sig: Sig.empty,
        sourceText: '',
        ticked: true,
        clear: false,
      ),
    );
    editTakeaway(who, _takeaways[who]!.length - 1, name, instruction);
  }

  /// What the analyser hears from a person: only the ticked medicine rows.
  String _validatedText(SourceKind who) {
    final rows = _takeaways[who];
    if (rows == null) return wordsOf(who);
    if (who == SourceKind.doctor && verifier == Verifier.doctor) {
      return [
        for (final t in rows)
          if (!t.isNote && t.doctorVerified) doctorLine(t),
      ].join('\n');
    }
    return [
      for (final t in rows)
        if (t.ticked && !t.isNote && t.sourceText.isNotEmpty) t.sourceText,
    ].join('\n');
  }

  // ── Step 2: who verifies ────────────────────────────────────────────────

  /// Me until someone says the doctor is checking.
  Verifier get verifier => visit.verifiedBy ?? Verifier.me;

  void setVerifier(Verifier v) {
    visit.verifiedBy = v;
    repository.save(visit);
    notifyListeners();
  }

  void setCheck(SourceKind who, int i, CheckPoint point, CheckState state) {
    _takeaways[who]![i].checks[point] = state;
    notifyListeners();
  }

  /// What a doctor-verified row tells the analysis: only the points they
  /// confirmed. A point marked "not provided" is left out, so the merge sees
  /// it as missing — an amber card, not a guess.
  static String doctorLine(Takeaway t) {
    bool ok(CheckPoint p) => t.checks[p] == CheckState.confirmed;
    final sig = t.sig;
    final parts = <String>[t.name];
    if (ok(CheckPoint.timing)) {
      if (sig.sos) {
        parts.add('SOS');
      } else if (sig.stat) {
        parts.add('STAT');
      } else {
        parts.addAll(sig.slots.map((s) => s.name));
      }
    }
    if (ok(CheckPoint.dose) && sig.unitsPerDose != 1) {
      parts.add(
        sig.unitsPerDose == .5
            ? 'half tablet'
            : '${sig.unitsPerDose.round()} tablets',
      );
    }
    if (ok(CheckPoint.food)) {
      if (sig.food == FoodTiming.before) parts.add('before food');
      if (sig.food == FoodTiming.after) parts.add('after food');
    }
    if (ok(CheckPoint.duration)) {
      if (sig.everyNDays != null) parts.add('every ${sig.everyNDays} days');
      if (sig.durationDays != null) parts.add('for ${sig.durationDays} days');
    }
    if (ok(CheckPoint.purpose) && t.purpose != null) {
      parts.add('${t.purpose} ke liye');
    }
    return parts.join(' ');
  }

  // ── Note for the caretaker ─────────────────────────────────────────────

  void setCaretakerNote(String text) {
    visit.caretakerNote = text;
    repository.save(visit);
    notifyListeners();
  }

  void setNotePriority(NotePriority p) {
    visit.notePriority = p;
    repository.save(visit);
    notifyListeners();
  }

  // ── Step 3: photos ──────────────────────────────────────────────────────

  final List<PhotoCandidate> candidates = [];
  int ocrReads = 0;

  int get selectedCount => candidates.where((c) => c.selected).length;

  bool get photosReady =>
      candidates.any((c) => c.selected && c.label == PhotoLabel.prescription) ||
      visit.hasPrescription;

  /// Add photos from the camera, the gallery or the recent-photo scan, and
  /// read each one straight away. [hint] is what the user said it is.
  Future<void> addPhotos(Iterable<XFile> files, {PhotoLabel? hint}) async {
    final added = <PhotoCandidate>[];
    for (final f in files) {
      final c = PhotoCandidate(
        path: f.path,
        label: hint ?? PhotoLabel.prescription,
      );
      candidates.add(c);
      added.add(c);
    }
    notifyListeners();
    for (final c in added) {
      await _read(c, hinted: hint != null);
    }
  }

  /// Add a candidate whose text was already read — the recent-photo scan
  /// reads while it labels, and that text is reused here, never read twice.
  void addReadCandidate(String path, String text) {
    final c = PhotoCandidate(path: path, label: PhotoLabel.prescription);
    c.ocrText = text;
    _label(c, ContentGate.judgeText(text), hinted: false);
    candidates.add(c);
    notifyListeners();
  }

  Future<void> _read(PhotoCandidate c, {required bool hinted}) async {
    if (c.ocrText != null) return; // read once
    c.reading = true;
    notifyListeners();
    final result = await recogniser.read(c.path);
    ocrReads++;
    c.reading = false;
    if (result.unsupported) {
      // Keep it, as the user labelled it, and say it could not be read.
      c.unreadable = true;
      c.selected = true;
    } else {
      c.ocrText = result.text;
      _label(c, ContentGate.judgeText(result.text), hinted: hinted);
    }
    notifyListeners();
  }

  void _label(PhotoCandidate c, ContentVerdict v, {required bool hinted}) {
    c.evidence = v.evidence;
    switch (v.kind) {
      case ContentKind.prescription:
        c.label = PhotoLabel.prescription;
      case ContentKind.bill:
        c.label = PhotoLabel.bill;
      case ContentKind.medicineStrip:
        c.label = PhotoLabel.strip;
      case ContentKind.medicalOther:
        if (!hinted) c.label = PhotoLabel.prescription;
      case ContentKind.notMedical:
        // Never hidden: unticked, with the reason shown, and overridable.
        c.selected = false;
        c.reason = 'notMedical';
    }
  }

  void setLabel(PhotoCandidate c, PhotoLabel label) {
    c.label = label;
    c.selected = true;
    notifyListeners();
  }

  void toggleSelected(PhotoCandidate c) {
    c.selected = !c.selected;
    notifyListeners();
  }

  /// Only ticked photos enter the visit, and only now, when the step is left.
  /// Scanning is an assistant, not an import.
  Future<void> commitPhotos() async {
    final paths = visit.photos.map((p) => p.path).toSet();
    for (final c in candidates.where((c) => c.selected)) {
      if (paths.contains(c.path)) continue;
      final kept = await media.keep(
        visit.id,
        XFile(c.path),
        name: '${c.label.name}_${visit.photos.length + 1}',
      );
      visit.photos.add(
        VisitPhoto(path: kept, label: c.label, ocrText: c.ocrText),
      );
    }
    await repository.save(visit);
  }

  // ── Step 6: processing ──────────────────────────────────────────────────

  AnalysisResult? analysis;
  bool _analysing = false;
  bool get analysing => _analysing;

  /// Rows read online (with consent) that join the same merge.
  final List<Mention> onlineMentions = [];

  Future<void> runAnalysis() async {
    _analysing = true;
    notifyListeners();
    final texts = <SourceText>[
      SourceText(SourceKind.doctor, _validatedText(SourceKind.doctor)),
      SourceText(SourceKind.chemist, _validatedText(SourceKind.chemist)),
      for (final p in visit.photos)
        if (p.ocrText != null && _sourceOf(p.label) != null)
          SourceText(_sourceOf(p.label)!, p.ocrText!),
    ];
    analysis = OfflineAnalyser.analyse(texts, extra: onlineMentions);
    decisions
      ..clear()
      ..addEntries(
        analysis!.rows.map((r) => MapEntry(r.id, MedicineDecision())),
      );
    _analysing = false;
    notifyListeners();
  }

  static SourceKind? _sourceOf(PhotoLabel l) => switch (l) {
    PhotoLabel.prescription => SourceKind.prescription,
    PhotoLabel.bill => SourceKind.bill,
    PhotoLabel.strip => SourceKind.strip,
    PhotoLabel.medicalOther => SourceKind.prescription,
    PhotoLabel.notMedical => null,
  };

  // ── Step 7: medicines ───────────────────────────────────────────────────

  final Map<String, MedicineDecision> decisions = {};

  List<MergedMedicine> get rows => analysis?.rows ?? const [];

  MedicineDecision decisionOf(MergedMedicine m) =>
      decisions.putIfAbsent(m.id, MedicineDecision.new);

  bool get allDecided => rows.every((r) => decisionOf(r).decided);

  List<MergedMedicine> get keptRows =>
      rows.where((r) => !decisionOf(r).leftOut).toList();

  /// A red card cannot be confirmed until a person has picked a side.
  bool canConfirm(MergedMedicine m) {
    final d = decisionOf(m);
    return m.verdict != Verdict.red || d.chosen != null || d.editedSig != null;
  }

  void confirm(MergedMedicine m) {
    if (!canConfirm(m)) return;
    final d = decisionOf(m);
    d
      ..confirmed = !d.confirmed
      ..leftOut = false;
    notifyListeners();
  }

  void choose(MergedMedicine m, Mention side) {
    decisionOf(m)
      ..chosen = side
      ..confirmed = true
      ..leftOut = false;
    notifyListeners();
  }

  void leaveOut(MergedMedicine m) {
    final d = decisionOf(m);
    d
      ..leftOut = !d.leftOut
      ..confirmed = false;
    notifyListeners();
  }

  void editRow(MergedMedicine m, String name, String instruction) {
    final parsed = SigParser.parseLine('$name $instruction');
    decisionOf(m)
      ..editedName = name.trim().toUpperCase()
      ..editedSig = parsed.sig.copyWith(unresolved: const [])
      ..confirmed = true
      ..leftOut = false;
    notifyListeners();
  }

  /// The Sig that will reach the schedule: a person's fix, else the side
  /// they chose, else what the evidence proposed.
  Sig finalSig(MergedMedicine m) {
    final d = decisionOf(m);
    if (d.editedSig != null) return d.editedSig!;
    if (d.chosen != null) {
      return d.chosen!.sig.copyWith(unresolved: const []);
    }
    return m.sig.copyWith(unresolved: const []);
  }

  String finalName(MergedMedicine m) => decisionOf(m).editedName ?? m.name;

  // ── Step 8: placement ───────────────────────────────────────────────────

  List<Placement> placements = const [];

  void _placeMedicines() {
    final today = dayOf(_clock());
    placements = PlacementAdvisor.advise(
      incoming: [
        for (final m in keptRows)
          ScheduledMedicine(
            id: MergedMedicine.idFor(finalName(m)),
            name: finalName(m),
            strength: m.strength,
            sig: finalSig(m),
            startDate: today,
            purpose: m.purpose,
          ),
      ],
      existing: store.active(),
      today: today,
    );
  }

  /// Approve and add. Returns the medicines that went onto the schedule.
  Future<List<ScheduledMedicine>> approve() async {
    final approved = [for (final p in placements) p.medicine];
    await store.approve(
      visitId: visit.id,
      approved: approved,
      at: _clock(),
      evidence: [
        for (final s in analysis?.sourcesRead ?? const <SourceKind>{}) s.name,
      ],
      caretakerNote: visit.caretakerNote.trim().isEmpty
          ? null
          : visit.caretakerNote.trim(),
      notePriority: visit.notePriority.name,
    );
    await repository.clear();
    return approved;
  }

  @override
  void dispose() {
    _recogniser?.close();
    super.dispose();
  }
}
