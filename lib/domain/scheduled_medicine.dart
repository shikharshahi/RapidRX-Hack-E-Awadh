import 'sig.dart';

/// A medicine a person approved, now on the daily schedule.
class ScheduledMedicine {
  const ScheduledMedicine({
    required this.id,
    required this.name,
    required this.sig,
    required this.startDate,
    this.strength,
    this.active = true,
    this.purpose,
  });

  final String id;

  /// English letters, exactly as printed.
  final String name;
  final String? strength;
  final Sig sig;

  /// Midnight of the day it starts.
  final DateTime startDate;
  final bool active;

  /// Quoted from the doctor, never inferred.
  final String? purpose;

  ScheduledMedicine copyWith({Sig? sig, bool? active, DateTime? startDate}) =>
      ScheduledMedicine(
        id: id,
        name: name,
        strength: strength,
        sig: sig ?? this.sig,
        startDate: startDate ?? this.startDate,
        active: active ?? this.active,
        purpose: purpose,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    if (strength != null) 'strength': strength,
    'sig': sig.toJson(),
    'startDate': startDate.toIso8601String(),
    'active': active,
    if (purpose != null) 'purpose': purpose,
  };

  factory ScheduledMedicine.fromJson(Map<String, Object?> j) =>
      ScheduledMedicine(
        id: j['id']! as String,
        name: j['name']! as String,
        strength: j['strength'] as String?,
        sig: Sig.fromJson((j['sig']! as Map).cast<String, Object?>()),
        startDate: DateTime.parse(j['startDate']! as String),
        active: j['active'] as bool? ?? true,
        purpose: j['purpose'] as String?,
      );
}

/// One approved visit, as the "My prescriptions" list shows it.
class PrescriptionRecord {
  const PrescriptionRecord({
    required this.id,
    required this.addedAt,
    required this.medicineNames,
  });

  final String id;
  final DateTime addedAt;
  final List<String> medicineNames;

  Map<String, Object?> toJson() => {
    'id': id,
    'addedAt': addedAt.toIso8601String(),
    'medicineNames': medicineNames,
  };

  factory PrescriptionRecord.fromJson(Map<String, Object?> j) =>
      PrescriptionRecord(
        id: j['id']! as String,
        addedAt: DateTime.parse(j['addedAt']! as String),
        medicineNames: [
          for (final n in j['medicineNames']! as List) n as String,
        ],
      );
}

/// Midnight of [d]. Every comparison of days goes through here.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
