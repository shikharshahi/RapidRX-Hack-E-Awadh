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

  AppLanguage? get language => AppLanguage.fromCode(_prefs.getString(_language));
  Future<void> setLanguage(AppLanguage l) => _prefs.setString(_language, l.code);

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

  /// Forget who this phone belongs to. Device choices stay.
  Future<void> clearIdentity() async {
    for (final key in [_role, _phone, _name, _backupPhone, _pinHash]) {
      await _prefs.remove(key);
    }
  }
}
