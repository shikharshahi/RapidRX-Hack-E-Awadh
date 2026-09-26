import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/feedback/haptics.dart';
import '../../core/feedback/pressable.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/strings_records.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../onboarding/splash_screen.dart';
import 'demo_records.dart';
import 'record_checker.dart';
import 'record_ports.dart';

/// After the splash, before language. Both languages are on the screen,
/// because none has been chosen yet.
class RecordCheckScreen extends StatefulWidget {
  const RecordCheckScreen({
    super.key,
    required this.checker,
    required this.onContinue,
    required this.onDemo,
    this.duration = const Duration(seconds: 5),
    this.lead = AppLanguage.en,
  });

  final RecordChecker checker;
  final VoidCallback onContinue;
  final VoidCallback onDemo;

  /// How long the "checking" line stays up. Tests pass a few milliseconds.
  /// A real [Future.delayed] under fake test time never fires (see GOTCHAS),
  /// so this is a [Timer], same as the splash.
  final Duration duration;

  /// Which language leads. The other is still shown. Goldens pin it.
  final AppLanguage lead;

  @override
  State<RecordCheckScreen> createState() => _RecordCheckScreenState();
}

class _RecordCheckScreenState extends State<RecordCheckScreen> {
  Timer? _wait;
  RecordDecision? _decision;
  bool _pin = false;
  String? _pinError;
  bool _locked = false;
  final _pinController = TextEditingController();

  AppStrings get _lead => AppStrings(widget.lead);
  AppStrings get _other => AppStrings(
    widget.lead == AppLanguage.hi ? AppLanguage.en : AppLanguage.hi,
  );

  @override
  void initState() {
    super.initState();
    _wait = Timer(widget.duration, _finishWait);
  }

  Future<void> _finishWait() async {
    final decision = await widget.checker.decide();
    if (!mounted) return;
    if (decision.prompt == RecordPrompt.done) {
      widget.onContinue();
      return;
    }
    setState(() => _decision = decision);
  }

  @override
  void dispose() {
    _wait?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decision = _decision;
    if (decision == null) return _checking();
    if (_locked) return _lockedView();
    if (_pin) return _pinView();
    return switch (decision.prompt) {
      RecordPrompt.restore => _question(
        title: _lead.recordRestoreQuestion,
        why: _other.recordRestoreQuestion,
        summary: decision.manifest,
        onYes: _yesRestore,
        onNo: _noRestore,
      ),
      RecordPrompt.demo => _question(
        title: _lead.recordDemoQuestion,
        why: _other.recordDemoQuestion,
        preview: decision.preview,
        onYes: _yesDemo,
        onNo: _noDemo,
      ),
      RecordPrompt.corrupt => _corrupt(),
      RecordPrompt.done ||
      RecordPrompt.pin ||
      RecordPrompt.locked => _checking(),
    };
  }

  Widget _checking() {
    return OnboardingScaffold(
      title: _lead.recordChecking,
      why: _other.recordChecking,
      voiceText: '${_lead.recordChecking} ${_other.recordChecking}',
      voiceLanguage: AppLanguage.hi,
      children: const [Center(child: LoadingBar(width: 160))],
    );
  }

  Widget _question({
    required String title,
    required String why,
    RecordManifest? summary,
    DemoPreview? preview,
    required VoidCallback onYes,
    required VoidCallback onNo,
  }) {
    final date = summary == null
        ? preview?.date
        : summary.updatedAt.split('T').first;
    final medicines = summary?.count('medicines') ?? preview?.medicines ?? 0;
    final prescriptions =
        summary?.count('prescriptions') ?? preview?.prescriptions ?? 0;
    final doses = summary?.count('doseLogs') ?? preview?.doses ?? 0;
    return OnboardingScaffold(
      title: title,
      why: why,
      voiceText: '$title $why',
      voiceLanguage: AppLanguage.hi,
      children: [
        if (date != null) ...[
          Text(
            _lead.recordSummary(
              date: date,
              medicines: medicines,
              prescriptions: prescriptions,
              doses: doses,
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            _other.recordSummary(
              date: date,
              medicines: medicines,
              prescriptions: prescriptions,
              doses: doses,
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
        ],
        Pressable(
          child: FilledButton(onPressed: onYes, child: Text(_lead.recordYes)),
        ),
        const SizedBox(height: 12),
        Pressable(
          child: OutlinedButton(onPressed: onNo, child: Text(_lead.recordNo)),
        ),
      ],
    );
  }

  Widget _pinView() {
    return OnboardingScaffold(
      title: _lead.recordPinTitle,
      why: _other.recordPinTitle,
      voiceText: '${_lead.recordPinTitle} ${_other.recordPinTitle}',
      voiceLanguage: AppLanguage.hi,
      children: [
        BigTextField(
          controller: _pinController,
          hint: _lead.recordPinTitle,
          digits: 4,
          obscure: true,
          errorText: _pinError,
          onSubmitted: (_) => _submitPin(),
        ),
        const SizedBox(height: 28),
        Pressable(
          child: FilledButton(
            onPressed: _submitPin,
            child: Text(_lead.recordContinue),
          ),
        ),
      ],
    );
  }

  Widget _lockedView() {
    final minutes = widget.checker.lockFor.inMinutes;
    return OnboardingScaffold(
      title: _lead.recordPinLocked(minutes),
      why: _other.recordPinLocked(minutes),
      voiceText:
          '${_lead.recordPinLocked(minutes)} ${_other.recordPinLocked(minutes)}',
      voiceLanguage: AppLanguage.hi,
      children: [
        Pressable(
          child: OutlinedButton(
            onPressed: _noRestore,
            child: Text(_lead.recordNotNow),
          ),
        ),
      ],
    );
  }

  Widget _corrupt() {
    return OnboardingScaffold(
      title: _lead.recordCorrupt,
      why: _other.recordCorrupt,
      voiceText: '${_lead.recordCorrupt} ${_other.recordCorrupt}',
      voiceLanguage: AppLanguage.hi,
      children: [
        Pressable(
          child: FilledButton(
            onPressed: widget.onContinue,
            child: Text(_lead.recordContinue),
          ),
        ),
      ],
    );
  }

  void _yesRestore() {
    Haptics.tap();
    if (widget.checker.isLocked) {
      setState(() => _locked = true);
      return;
    }
    setState(() {
      _pin = true;
      _pinError = null;
    });
  }

  Future<void> _noRestore() async {
    Haptics.tap();
    await widget.checker.declineRestore();
    if (mounted) widget.onContinue();
  }

  Future<void> _yesDemo() async {
    Haptics.tap();
    await widget.checker.acceptDemo();
    if (mounted) widget.onDemo();
  }

  Future<void> _noDemo() async {
    Haptics.tap();
    await widget.checker.declineDemo();
    if (mounted) widget.onContinue();
  }

  Future<void> _submitPin() async {
    final pin = _pinController.text.trim();
    final attempt = await widget.checker.enterPin(pin);
    if (!mounted) return;
    switch (attempt) {
      case PinAttempt.ok:
        Haptics.confirm();
        widget.onContinue();
      case PinAttempt.wrong:
        Haptics.error();
        setState(
          () => _pinError = '${_lead.recordPinWrong}\n${_other.recordPinWrong}',
        );
      case PinAttempt.locked:
        Haptics.error();
        setState(() => _locked = true);
      case PinAttempt.rejected:
        Haptics.error();
        setState(() {
          _pin = false;
          _decision = const RecordDecision(RecordPrompt.corrupt);
        });
    }
  }
}
