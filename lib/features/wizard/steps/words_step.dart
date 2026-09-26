import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/mention.dart';
import '../../../platform/dictation.dart';
import '../../visit/capture_tools.dart';
import '../wizard_controller.dart';
import '../wizard_widgets.dart';
import '../write_note_screen.dart';

/// Steps 1 and 4: what the doctor said, what the chemist said.
///
/// One primary button — Speak. Writing is the alternative, on a full page.
/// Saving the audio is a separate, secondary choice, off by default: the
/// recording is for the family, and it is not what gets cross-checked.
class WordsStep extends StatefulWidget {
  const WordsStep({
    super.key,
    required this.controller,
    required this.who,
    required this.dictation,
    required this.audio,
  });

  final VisitWizardController controller;
  final SourceKind who;
  final Dictation dictation;
  final AudioCapture audio;

  @override
  State<WordsStep> createState() => _WordsStepState();
}

class _WordsStepState extends State<WordsStep> {
  bool _listening = false;
  bool _recording = false;
  String _before = '';

  VisitWizardController get c => widget.controller;

  @override
  void dispose() {
    if (_listening) widget.dictation.stop();
    super.dispose();
  }

  Future<void> _toggleSpeak() async {
    final s = L10n.of(context);
    if (_listening) {
      await widget.dictation.stop();
      setState(() => _listening = false);
      return;
    }
    _before = c.wordsOf(widget.who).trim();
    final ok = await widget.dictation.listen(
      language: L10n.languageOf(context),
      onWords: (words, done) {
        final joined = [_before, words].where((x) => x.isNotEmpty).join(' ');
        c.setWords(widget.who, joined);
        if (done && mounted) setState(() => _listening = false);
      },
    );
    if (!mounted) return;
    if (!ok) {
      _say(s.dictationUnavailable);
      return;
    }
    setState(() => _listening = true);
  }

  Future<void> _write() async {
    final text = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => WriteNoteScreen(initial: c.wordsOf(widget.who)),
      ),
    );
    if (text != null) c.setWords(widget.who, text);
  }

  Future<void> _toggleAudio() async {
    final s = L10n.of(context);
    if (_recording) {
      final file = await widget.audio.stop();
      setState(() => _recording = false);
      if (file != null) await c.keepAudio(widget.who, file);
      return;
    }
    if (!await widget.audio.start()) {
      _say(s.micUnavailable);
      return;
    }
    setState(() => _recording = true);
  }

  void _say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final words = c.wordsOf(widget.who).trim();
    final audioKept = widget.who == SourceKind.doctor
        ? c.visit.doctorAudioPath != null
        : c.visit.chemistAudioPath != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        StepIntro(
          widget.who == SourceKind.doctor ? s.doctorWordsWhy : s.pharmacyWhy,
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(72),
            backgroundColor: _listening ? AppColors.red : AppColors.ink,
          ),
          icon: Icon(
            _listening ? Icons.stop_rounded : Icons.graphic_eq_rounded,
            size: 30,
          ),
          label: Text(_listening ? s.listening : s.speak),
          onPressed: _toggleSpeak,
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          icon: const Icon(Icons.edit_outlined, size: 26),
          label: Text(s.writeIt),
          onPressed: _write,
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: _write,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppColors.hairline, width: 2),
            ),
            child: Text(
              words.isEmpty ? s.nothingWrittenYet : words,
              style: words.isEmpty
                  ? text.bodySmall?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    )
                  : text.bodyMedium,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              audioKept ? Icons.check_circle_rounded : Icons.mic_none_rounded,
              color: audioKept ? AppColors.green : AppColors.inkSoft,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audioKept ? s.audioSaved : s.alsoSaveAudio,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    s.alsoSaveAudioWhy,
                    style: text.bodySmall?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _toggleAudio,
              child: Text(
                _recording ? s.stopRecording : s.speak,
                style: TextStyle(
                  color: _recording ? AppColors.red : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
