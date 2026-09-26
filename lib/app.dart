import 'package:flutter/material.dart';

import 'core/app_state.dart';
import 'core/dev_flags.dart';
import 'core/l10n/app_strings.dart';
import 'core/l10n/l10n.dart';
import 'core/storage/app_prefs.dart';
import 'core/theme/app_theme.dart';
import 'core/voice/voice_guide.dart';
import 'core/widgets/phone_shell.dart';
import 'features/caregiver/caregiver_home.dart';
import 'features/health/health_profile_controller.dart';
import 'features/health/health_profile_screen.dart';
import 'features/health/pmjay_client.dart';
import 'features/onboarding/language_screen.dart';
import 'features/onboarding/phone_screens.dart';
import 'features/onboarding/role_screen.dart';
import 'features/onboarding/saving_screen.dart';
import 'features/onboarding/splash_screen.dart';
import 'features/onboarding/voice_help_screen.dart';
import 'features/patient/patient_menu.dart';

enum _Stage {
  splash,
  language,
  saving,
  voice,
  phone,
  phoneOtp,
  profile,
  pin,
  pinConfirm,
  role,
  health,
  ready,
}

class RapidRxApp extends StatefulWidget {
  const RapidRxApp({
    super.key,
    required this.prefs,
    this.stageDelay = const Duration(seconds: 3),
    this.showSplash = true,
    this.voice,
    this.pmjay,
    this.resumeOnboarding = false,
  });

  final AppPrefs prefs;

  /// How long the splash and "saving" screens stay up. Injectable, because a
  /// real three-second `Future.delayed` under fake test time hangs forever.
  final Duration stageDelay;

  final bool showSplash;

  /// Injected by tests; the app builds its own.
  final VoiceGuide? voice;

  /// Injected by tests; the app uses the demo lookup.
  final PmjayClient? pmjay;

  /// Honour the resume rule even while DevFlags.alwaysShowOnboarding is on,
  /// so the rule itself can be tested.
  final bool resumeOnboarding;

  @override
  State<RapidRxApp> createState() => _RapidRxAppState();
}

class _RapidRxAppState extends State<RapidRxApp> {
  late final AppState _state = AppState(widget.prefs)..addListener(_syncVoice);
  late final VoiceGuide _voice = widget.voice ?? VoiceGuide();

  @override
  void initState() {
    super.initState();
    _syncVoice();
  }

  /// Voice speaks only when the build allows it and the user asked for it.
  void _syncVoice() {
    final on = DevFlags.voiceEnabled && _state.voiceHelp;
    if (_voice.enabled && !on) _voice.stopAll();
    _voice.enabled = on;
  }

  late _Stage _stage = widget.showSplash ? _Stage.splash : _resume();

  // Held between screens during onboarding, written once confirmed.
  String? _phone;
  String? _pendingPin;
  String? _pinError;

  AppPrefs get _prefs => widget.prefs;

  // This State sits above the L10n scope, so it builds its own strings.
  AppStrings get _strings => AppStrings(_state.language);

  /// Where to pick up on launch, in this exact order.
  _Stage _resume() {
    if (DevFlags.alwaysShowOnboarding && !widget.resumeOnboarding) {
      return _Stage.language;
    }
    if (_prefs.language == null) return _Stage.language;
    if (_prefs.voiceHelp == null) return _Stage.voice;
    if (_prefs.phoneNumber == null) return _Stage.phone;
    if (_prefs.name == null) return _Stage.profile;
    if (!_prefs.hasPin) return _Stage.pin;
    if (_prefs.role == null) return _Stage.role;
    if (_prefs.role == AppRole.patient && _prefs.age == null) {
      return _Stage.health;
    }
    return _Stage.ready;
  }

  void _go(_Stage stage) => setState(() => _stage = stage);

  @override
  void dispose() {
    _voice.stopAll();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: ListenableBuilder(
        listenable: _state,
        builder: (context, _) => MaterialApp(
          title: 'RapidRX',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          // Scopes live in the builder, not around `home`, so pushed routes
          // can find them too.
          builder: (context, child) => L10n(
            language: _state.language,
            child: VoiceScope(
              guide: _voice,
              child: PhoneShell(child: child!),
            ),
          ),
          home: KeyedSubtree(key: ValueKey(_stage), child: _screen()),
        ),
      ),
    );
  }

  Widget _screen() {
    switch (_stage) {
      case _Stage.splash:
        return SplashScreen(
          duration: widget.stageDelay,
          onDone: () => _go(_resume()),
        );

      case _Stage.language:
        return LanguageScreen(
          onChosen: (language) async {
            await _state.setLanguage(language);
            _go(_Stage.saving);
          },
        );

      case _Stage.saving:
        return SavingScreen(
          duration: widget.stageDelay,
          onDone: () => _go(_Stage.voice),
        );

      case _Stage.voice:
        return VoiceHelpScreen(
          current: _prefs.voiceHelp,
          onChosen: (on) async {
            await _state.setVoiceHelp(on);
            _go(_Stage.phone);
          },
        );

      case _Stage.phone:
        return PhoneScreen(
          initial: _phone ?? _prefs.phoneNumber,
          onSubmitted: (phone) {
            _phone = phone;
            _go(_Stage.phoneOtp);
          },
        );

      case _Stage.phoneOtp:
        return OtpScreen(
          phone: _phone ?? '',
          onVerified: () async {
            await _prefs.setPhoneNumber(_phone!);
            _go(_Stage.profile);
          },
        );

      case _Stage.profile:
        return ProfileScreen(
          initialName: _prefs.name,
          onSubmitted: (name) async {
            await _prefs.setName(name);
            _go(_Stage.pin);
          },
        );

      case _Stage.pin:
        return PinScreen(
          errorText: _pinError,
          onSubmitted: (pin) {
            _pendingPin = pin;
            _pinError = null;
            _go(_Stage.pinConfirm);
          },
        );

      case _Stage.pinConfirm:
        return PinScreen(
          confirming: true,
          onSubmitted: (pin) async {
            if (pin != _pendingPin) {
              _pendingPin = null;
              _pinError = _strings.pinMismatch;
              _go(_Stage.pin);
              return;
            }
            await _prefs.setPin(pin);
            _pendingPin = null;
            // A fresh onboarding asks the role again.
            await _state.setRole(null);
            _go(_Stage.role);
          },
        );

      case _Stage.role:
        return RoleScreen(onChosen: _roleChosen);

      case _Stage.health:
        return HealthProfileScreen(
          controller: HealthProfileController(
            prefs: _prefs,
            pmjay: widget.pmjay,
          ),
          onDone: () => _go(_Stage.ready),
        );

      case _Stage.ready:
        return switch (_state.role) {
          // "Change who is using the app" from a home screen lands here.
          null => RoleScreen(onChosen: _roleChosen),
          AppRole.patient => PatientMenu(onRestart: _restart),
          AppRole.caregiver => CaregiverHome(onRestart: _restart),
        };
    }
  }

  /// Health details only make sense for a patient, so they come after the
  /// role — and only for a patient who has not given them yet.
  Future<void> _roleChosen(AppRole role) async {
    await _state.setRole(role);
    _go(
      role == AppRole.patient && _prefs.age == null
          ? _Stage.health
          : _Stage.ready,
    );
  }

  Future<void> _restart() async {
    await _prefs.clearIdentity();
    await _state.setRole(null);
    _phone = null;
    _go(_Stage.language);
  }
}
