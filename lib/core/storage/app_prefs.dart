import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_language.dart';

enum AppRole { patient, caregiver }

/// Device choices and identity, in `shared_preferences`.
///
/// Everything here is local to this phone. A production build moves the
/// medical data to Firestore with an offline cache (ADR-6); the device choices
/// — language, voice, role — stay here, because they belong to the phone, not
/// to the person.
class AppPrefs {
  AppPrefs(this._prefs);

  final SharedPreferences _prefs;

  /// The same store, for the stores that live beside these choices.
  SharedPreferences get raw => _prefs;

  static Future<AppPrefs> load() async =>
      AppPrefs(await SharedPreferences.getInstance());

  static const _role = 'app_role';
  static const _language = 'app_language';
  static const _voiceHelp = 'voice_help';
  static const _phone = 'phone_number';
  static const _name = 'user_name';
  static const _backupPhone = 'backup_phone';
  static const _pinHash = 'pin_hash';

  AppRole? get role => switch (_prefs.getString(_role)) {
    'patient' => AppRole.patient,
    'caregiver' => AppRole.caregiver,
    _ => null,
  };
  Future<void> setRole(AppRole role) => _prefs.setString(_role, role.name);

  AppLanguage? get language =>
      AppLanguage.fromCode(_prefs.getString(_language));
  Future<void> setLanguage(AppLanguage l) =>
      _prefs.setString(_language, l.code);

  bool? get voiceHelp => _prefs.getBool(_voiceHelp);
  Future<void> setVoiceHelp(bool on) => _prefs.setBool(_voiceHelp, on);

  String? get phoneNumber => _prefs.getString(_phone);
  Future<void> setPhoneNumber(String phone) => _prefs.setString(_phone, phone);

  String? get name => _prefs.getString(_name);
  Future<void> setName(String name) => _prefs.setString(_name, name.trim());

  /// The family member's number. This is where caregiver alerts go.
  String? get backupPhone => _prefs.getString(_backupPhone);
  Future<void> setBackupPhone(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      await _prefs.remove(_backupPhone);
    } else {
      await _prefs.setString(_backupPhone, phone.trim());
    }
  }

  bool get hasPin => _prefs.getString(_pinHash) != null;

  /// Stored as a SHA-256 hash. The PIN itself never touches the disk.
  Future<void> setPin(String pin) => _prefs.setString(_pinHash, hashPin(pin));

  bool checkPin(String pin) => _prefs.getString(_pinHash) == hashPin(pin);

  static String hashPin(String pin) =>
      sha256.convert(utf8.encode('rapidrx:$pin')).toString();

  // ── Health profile (patients only) ──────────────────────────────────────
  static const _age = 'health_age';
  static const _height = 'health_height_cm';
  static const _weight = 'health_weight_kg';
  static const _ayushmanId = 'ayushman_id';
  static const _ayushmanCard = 'ayushman_card';
  static const _ayushmanFound = 'ayushman_card_found';

  /// A card looked up in the background, waiting for "yes, this is me".
  String? get foundAyushmanCardJson => _prefs.getString(_ayushmanFound);

  Future<void> setFoundAyushmanCard(String? json) =>
      _setOrRemoveString(_ayushmanFound, json);

  /// The patient said the found card is theirs.
  Future<void> confirmFoundAyushmanCard(String pmjayId) async {
    final json = foundAyushmanCardJson;
    if (json == null) return;
    await _prefs.setString(_ayushmanCard, json);
    await _prefs.setString(_ayushmanId, pmjayId);
    await _prefs.remove(_ayushmanFound);
  }

  /// Required for a patient; null until the health screen is done.
  int? get age => _prefs.getInt(_age);
  int? get heightCm => _prefs.getInt(_height);
  int? get weightKg => _prefs.getInt(_weight);
  String? get ayushmanId => _prefs.getString(_ayushmanId);

  /// The card the patient confirmed as theirs, as JSON.
  String? get ayushmanCardJson => _prefs.getString(_ayushmanCard);

  Future<void> setHealth({
    required int age,
    int? heightCm,
    int? weightKg,
    String? ayushmanId,
    String? ayushmanCardJson,
  }) async {
    await _prefs.setInt(_age, age);
    await _setOrRemoveInt(_height, heightCm);
    await _setOrRemoveInt(_weight, weightKg);
    await _setOrRemoveString(_ayushmanId, ayushmanId);
    await _setOrRemoveString(_ayushmanCard, ayushmanCardJson);
  }

  Future<void> _setOrRemoveInt(String key, int? v) =>
      v == null ? _prefs.remove(key) : _prefs.setInt(key, v);

  Future<void> _setOrRemoveString(String key, String? v) =>
      v == null || v.isEmpty ? _prefs.remove(key) : _prefs.setString(key, v);

  static const _identityKeys = [
    _role,
    _phone,
    _name,
    _backupPhone,
    _pinHash,
    _age,
    _height,
    _weight,
    _ayushmanId,
    _ayushmanCard,
    _ayushmanFound,
  ];

  /// Forget who this phone belongs to. Device choices stay.
  Future<void> clearIdentity() async {
    for (final key in _identityKeys) {
      await _prefs.remove(key);
    }
  }
}
