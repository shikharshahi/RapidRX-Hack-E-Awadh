import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/onboarding_scaffold.dart';

/// The hardcoded demo code.
///
/// No SMS is sent: Firebase phone auth needs the paid Blaze plan. The OTP
/// screen says so in a visible hint rather than pretending.
const demoOtp = '1234';

/// Your mobile number — ten digits, +91 shown.
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key, required this.onSubmitted, this.initial});

  final ValueChanged<String> onSubmitted;
  final String? initial;

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final digits = _controller.text.trim();
    if (digits.length != 10) {
      setState(() => _error = L10n.of(context).phoneInvalid);
      return;
    }
    widget.onSubmitted(digits);
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return OnboardingScaffold(
      title: s.phoneTitle,
      why: s.phoneWhy,
      children: [
        BigTextField(
          controller: _controller,
          hint: s.phoneHint,
          digits: 10,
          keyboardType: TextInputType.phone,
          errorText: _error,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 28),
        FilledButton(onPressed: _submit, child: Text(s.continueLabel)),
      ],
    );
  }
}

/// Enter the code. Used for the user's own number and, when given, for the
/// family member's number.
class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.phone,
    required this.onVerified,
    this.title,
  });

  final String phone;
  final VoidCallback onVerified;
  final String? title;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim() != demoOtp) {
      setState(() => _error = L10n.of(context).otpWrong);
      return;
    }
    widget.onVerified();
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return OnboardingScaffold(
      title: widget.title ?? s.otpTitle,
      why: s.otpSentTo(widget.phone),
      children: [
        BigTextField(
          controller: _controller,
          hint: s.otpHint,
          digits: 4,
          errorText: _error,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 28),
        FilledButton(onPressed: _submit, child: Text(s.verify)),
        const SizedBox(height: 20),
        HintPill(text: s.otpDemoHint),
      ],
    );
  }
}

/// Name, plus an optional family member's number.
///
/// The family number is where caregiver alerts go later, so if it is given it
/// gets its own code check.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.onSubmitted,
    this.initialName,
    this.initialBackup,
  });

  final void Function(String name, String? backupPhone) onSubmitted;
  final String? initialName;
  final String? initialBackup;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _name = TextEditingController(text: widget.initialName);
  late final _backup = TextEditingController(text: widget.initialBackup);
  String? _nameError;
  String? _backupError;

  @override
  void dispose() {
    _name.dispose();
    _backup.dispose();
    super.dispose();
  }

  void _submit() {
    final s = L10n.of(context);
    final name = _name.text.trim();
    final backup = _backup.text.trim();
    setState(() {
      _nameError = name.isEmpty ? s.nameMissing : null;
      _backupError =
          backup.isNotEmpty && backup.length != 10 ? s.phoneInvalid : null;
    });
    if (_nameError != null || _backupError != null) return;
    widget.onSubmitted(name, backup.isEmpty ? null : backup);
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return OnboardingScaffold(
      title: s.profileTitle,
      children: [
        BigTextField(
          controller: _name,
          hint: s.nameHint,
          errorText: _nameError,
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Flexible(
              child: Text(
                s.backupLabel,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            OptionalTag(text: s.optional),
          ],
        ),
        const SizedBox(height: 10),
        BigTextField(
          controller: _backup,
          hint: s.backupLabel,
          digits: 10,
          keyboardType: TextInputType.phone,
          errorText: _backupError,
        ),
        const SizedBox(height: 8),
        Text(
          s.backupWhy,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(onPressed: _submit, child: Text(s.continueLabel)),
      ],
    );
  }
}

/// Set a PIN, or confirm it. The confirm step is the same screen with a
/// different title and a check.
class PinScreen extends StatefulWidget {
  const PinScreen({
    super.key,
    required this.onSubmitted,
    this.confirming = false,
    this.errorText,
  });

  final ValueChanged<String> onSubmitted;
  final bool confirming;
  final String? errorText;

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.errorText;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _controller.text.trim();
    if (pin.length != 4) {
      setState(() => _error = L10n.of(context).pinInvalid);
      return;
    }
    widget.onSubmitted(pin);
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return OnboardingScaffold(
      title: widget.confirming ? s.pinConfirmTitle : s.pinTitle,
      why: widget.confirming ? s.pinConfirmWhy : s.pinWhy,
      children: [
        BigTextField(
          controller: _controller,
          hint: widget.confirming ? s.pinConfirmTitle : s.pinTitle,
          digits: 4,
          obscure: true,
          errorText: _error,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 28),
        FilledButton(onPressed: _submit, child: Text(s.continueLabel)),
      ],
    );
  }
}
