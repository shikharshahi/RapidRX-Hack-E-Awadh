import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'core/app_state.dart';
import 'core/dev_flags.dart';
import 'core/feedback/haptics.dart';
import 'core/l10n/app_strings.dart';
import 'core/l10n/l10n.dart';
import 'core/storage/app_prefs.dart';
import 'core/theme/app_theme.dart';
import 'core/voice/voice_guide.dart';
import 'core/widgets/phone_shell.dart';
import 'features/doses/alarm_launcher.dart';
import 'features/caregiver/caregiver_home.dart';
import 'features/health/health_profile_controller.dart';
import 'features/health/health_profile_screen.dart';
import 'features/health/pmjay_client.dart';
import 'features/medicines/medicine_store.dart';
import 'features/visit/media_store.dart';
import 'features/sync/sync_queue.dart';
import 'features/sync/sync_service.dart';
import 'platform/network_status.dart';
import 'platform/notices.dart';
import 'features/records/record_check_screen.dart';
import 'features/records/record_checker.dart';
import 'features/records/secure_record_store.dart';
import 'features/onboarding/language_screen.dart';
import 'features/onboarding/phone_screens.dart';
import 'features/onboarding/role_screen.dart';
import 'features/onboarding/saving_screen.dart';
import 'features/onboarding/splash_screen.dart';
import 'features/onboarding/voice_help_screen.dart';
import 'features/pairing/caretaker_confirm_screen.dart';
import 'features/pairing/caretaker_pairing.dart';
import 'features/pairing/caretaker_qr_screen.dart';
import 'features/pairing/caretaker_type_screen.dart';
import 'features/patient/patient_menu.dart';
import 'platform/dose_reminders.dart';

enum _Stage {
  splash,
  recordCheck,
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
  caretakerType,
  caretakerQr,
  caretakerConfirm,
  ready,
}

class RapidRxApp extends StatefulWidget {
  const RapidRxApp({
    super.key,
    required this.prefs,
    this.stageDelay = const Duration(seconds: 3),
    this.recordCheckDelay = const Duration(seconds: 5),
    this.showSplash = true,
    this.voice,
    this.pmjay,
    this.resumeOnboarding = false,
    this.reminders,
    this.enableSync = true,
  });

  final AppPrefs prefs;

  /// How long the splash and "saving" screens stay up. Injectable, because a
  /// real three-second `Future.delayed` under fake test time hangs forever.
  final Duration stageDelay;

  /// How long the device record check stays up. Same reason.
  final Duration recordCheckDelay;

  final bool showSplash;

  /// Injected by tests; the app builds its own.
  final VoiceGuide? voice;

  /// Injected by tests; the app uses the demo lookup.
  final PmjayClient? pmjay;

  /// Honour the resume rule even while DevFlags.alwaysShowOnboarding is on,
  /// so the rule itself can be tested.
  final bool resumeOnboarding;

  /// Injected by tests; the app uses the phone's alarm service.
  final DoseReminders? reminders;

  /// Off in tests that do not exercise syncing.
  final bool enableSync;

  @override
  State<RapidRxApp> createState() => _RapidRxAppState();
}

class _RapidRxAppState extends State<RapidRxApp> {
  late final AppState _state = AppState(widget.prefs)..addListener(_syncVoice);
  late final VoiceGuide _voice = widget.voice ?? VoiceGuide();
  final _navigator = GlobalKey<NavigatorState>();
  late final DoseAlarmRouter _alarms = DoseAlarmRouter(
    navigatorKey: _navigator,
    state: _state,
    reminders: widget.reminders,
  );
  late final CaretakerPairing _pairing = CaretakerPairing(prefs: _prefs);

  @override
  void initState() {
    super.initState();
    _syncVoice();
    // After the first frame, so there is a navigator to open the alarm on —
    // including the alarm that started the app from cold.
    WidgetsBinding.instance.addPostFrameCallback((_) => _alarms.start());
    _startSync();
  }

  /// Offline save and sync for the whole app: drains the queue whenever the
  /// connection comes back.
  Future<void> _startSync() async {
    if (!widget.enableSync) return;
    final queue = await SyncQueue.load();
    final store = await MedicineStore.load();
    if (!mounted) return;
    _state.sync = SyncService(
      queue: queue,
      network: NetworkStatus(),
      notices: Notices(),
      strings: AppStrings(_state.language),
      store: store,
      media: MediaStore(),
      pmjay: widget.pmjay,
      onPmjayCard: (card) =>
          _prefs.setFoundAyushmanCard(jsonEncode(card.toJson())),
    )..start();
    unawaited(_state.sync!.drainNow());
  }

  /// Voice speaks when the user asked for it, and through onboarding until
  /// they answer that question. The language screen comes first; it cannot
  /// wait for a Yes they have not heard.
  void _syncVoice() {
    final beforeAnswer = _stage.index <= _Stage.voice.index;
    final on = DevFlags.voiceEnabled && (beforeAnswer || _state.voiceHelp);
    if (_voice.enabled && !on) _voice.stopAll();
    _voice.enabled = on;
  }

  late _Stage _stage = widget.showSplash ? _Stage.splash : _resume();

  /// Set when language was just chosen, so the device check that follows
  /// returns to "saving" instead of asking for a language again.
  bool _languageJustChosen = false;

  // Held between screens during onboarding, written once confirmed.
  String? _phone;
  String? _pendingPin;
  String? _pinError;

  AppPrefs get _prefs => widget.prefs;

  // This State sits above the L10n scope, so it builds its own strings.
  AppStrings get _strings => AppStrings(_state.language);

  /// Demo values while [DevFlags.demoTools] is on. Null in a store build.
  String? _demo(String value) => DevFlags.demoTools ? value : null;

  /// Language before the device check: nothing is chosen yet, or this build
  /// shows onboarding on every launch.
  bool get _askLanguageFirst =>
      _prefs.language == null ||
      (DevFlags.alwaysShowOnboarding && !widget.resumeOnboarding);

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
    if (_prefs.role == AppRole.caregiver) return _caretakerNext();
    return _Stage.ready;
  }

  /// A caretaker is asked who they are to the patient, then shown their QR
  /// code — unless they are linked already, or said "later". "Later" is
  /// remembered, so a relaunch goes home instead of trapping them on the QR.
  _Stage _caretakerNext() {
    if (_prefs.caretakerType == null) return _Stage.caretakerType;
    if (_prefs.linkedPatientJson == null && !_prefs.caretakerPairLater) {
      return _Stage.caretakerQr;
    }
    return _Stage.ready;
  }

  void _go(_Stage stage) {
    setState(() => _stage = stage);
    _syncVoice();
  }

  @override
  void dispose() {
    _alarms.dispose();
    _state.sync?.dispose();
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
          navigatorKey: _navigator,
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
          onDone: () =>
              _go(_askLanguageFirst ? _Stage.language : _Stage.recordCheck),
        );

      case _Stage.recordCheck:
        return RecordCheckScreen(
          duration: widget.recordCheckDelay,
          lead: _state.language,
          checker: _records ??= RecordChecker(prefs: _prefs),
          onContinue: () {
            if (_languageJustChosen) {
              _languageJustChosen = false;
              _go(_Stage.saving);
              return;
            }
            _go(_resume());
          },
          onDemo: () {
            unawaited(_enterDemo());
          },
        );

      case _Stage.language:
        return LanguageScreen(
          onChosen: (language) async {
            await _state.setLanguage(language);
            _languageJustChosen = true;
            _go(_Stage.recordCheck);
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
          initial: _phone ?? _prefs.phoneNumber ?? _demo('9876543210'),
          onSubmitted: (phone) {
            _phone = phone;
            _go(_Stage.phoneOtp);
          },
        );

      case _Stage.phoneOtp:
        return OtpScreen(
          phone: _phone ?? '',
          initial: _demo(demoOtp),
          onVerified: () async {
            await _prefs.setPhoneNumber(_phone!);
            _go(_Stage.profile);
          },
        );

      case _Stage.profile:
        return ProfileScreen(
          // Same person the demo PM-JAY ID resolves to.
          initialName: _prefs.name ?? _demo('Geeta Mishra'),
          onSubmitted: (name) async {
            await _prefs.setName(name);
            _go(_Stage.pin);
          },
        );

      case _Stage.pin:
        return PinScreen(
          errorText: _pinError,
          initial: _demo('1234'),
          onSubmitted: (pin) {
            _pendingPin = pin;
            _pinError = null;
            _go(_Stage.pinConfirm);
          },
        );

      case _Stage.pinConfirm:
        return PinScreen(
          confirming: true,
          initial: _demo('1234'),
          onSubmitted: (pin) async {
            if (pin != _pendingPin) {
              Haptics.error();
              _pendingPin = null;
              _pinError = _strings.pinMismatch;
              _go(_Stage.pin);
              return;
            }
            await _prefs.setPin(pin);
            await (await SecureRecordStore.open()).rewrap(pin);
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
            sync: _state.sync,
          ),
          seedAge: _demo('64'),
          seedHeight: _demo('165'),
          seedWeight: _demo('58'),
          seedPmjay: _demo(MockPmjayClient.demoId),
          onDone: () => _go(_Stage.ready),
        );

      case _Stage.caretakerType:
        return CaretakerTypeScreen(
          current: _prefs.caretakerType,
          onChosen: (type) async {
            await _prefs.setCaretakerType(type);
            _go(_caretakerNext());
          },
        );

      case _Stage.caretakerQr:
        return CaretakerQrScreen(
          pairing: _pairing,
          onEnterCode: () => _go(_Stage.caretakerConfirm),
          onLater: () async {
            await _pairing.later();
            _go(_Stage.ready);
          },
        );

      case _Stage.caretakerConfirm:
        return CaretakerConfirmScreen(
          pairing: _pairing,
          onBack: () => _go(_Stage.caretakerQr),
          onLinked: () => _go(_Stage.ready),
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
  /// role — and only for a patient who has not given them yet. A caretaker
  /// says who they are to the patient, then gets a QR code.
  Future<void> _roleChosen(AppRole role) async {
    await _state.setRole(role);
    _go(switch (role) {
      AppRole.patient when _prefs.age == null => _Stage.health,
      AppRole.patient => _Stage.ready,
      AppRole.caregiver => _caretakerNext(),
    });
  }

  RecordChecker? _records;

  /// The fixture already wrote language, voice and role into preferences.
  /// [AppState] keeps its own copies, so they have to be pulled across or the
  /// menu still thinks nobody has chosen.
  Future<void> _enterDemo() async {
    await _state.setLanguage(_prefs.language ?? _state.language);
    await _state.setVoiceHelp(_prefs.voiceHelp ?? false);
    await _state.setRole(_prefs.role);
    if (mounted) _go(_Stage.ready);
  }

  Future<void> _restart() async {
    if (_prefs.demoUser) {
      await (await SecureRecordStore.open()).wipe(
        andBackup: _prefs.demoOwnsBackup,
      );
    }
    await _prefs.clearIdentity();
    await _state.setRole(null);
    _phone = null;
    _go(_Stage.language);
  }
}
