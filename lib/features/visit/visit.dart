/// What a photo turned out to be.
enum PhotoLabel { prescription, bill, strip, medicalOther, notMedical }

/// The four things a visit can carry. Only the prescription is required.
enum CaptureKind { prescriptionPhoto, doctorVoice, bill, chemistVoice }

/// One photo in a visit, with the text read from it on the device.
class VisitPhoto {
  VisitPhoto({
    required this.path,
    required this.label,
    this.ocrText,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  final String path;
  PhotoLabel label;

  /// Read once, while labelling, and reused by extraction. Never read twice.
  String? ocrText;
  final DateTime addedAt;

  Map<String, Object?> toJson() => {
    'path': path,
    'label': label.name,
    if (ocrText != null) 'ocrText': ocrText,
    'addedAt': addedAt.toIso8601String(),
  };

  factory VisitPhoto.fromJson(Map<String, Object?> j) => VisitPhoto(
    path: j['path']! as String,
    label: PhotoLabel.values.byName(j['label']! as String),
    ocrText: j['ocrText'] as String?,
    addedAt: DateTime.parse(j['addedAt']! as String),
  );
}

/// One trip to the doctor and the chemist.
///
/// Saved after every single capture (ADR-20), so an app killed mid-visit —
/// a phone call, a flat battery — loses nothing. Photos and audio are files;
/// only their paths live here.
class Visit {
  Visit({
    required this.id,
    DateTime? createdAt,
    this.doctorName,
    this.consent = false,
    this.doctorWords = '',
    this.chemistWords = '',
    this.doctorAudioPath,
    this.chemistAudioPath,
    List<VisitPhoto>? photos,
  }) : createdAt = createdAt ?? DateTime.now(),
       photos = photos ?? [];

  factory Visit.start() =>
      Visit(id: 'v${DateTime.now().millisecondsSinceEpoch}');

  final String id;
  final DateTime createdAt;
  String? doctorName;

  /// Consent is a gate, not a checkbox (ADR-21): nothing is captured before it.
  bool consent;

  /// What the doctor said, as text — dictated or written.
  String doctorWords;

  /// What the chemist said, as text.
  String chemistWords;

  String? doctorAudioPath;
  String? chemistAudioPath;
  final List<VisitPhoto> photos;

  Iterable<VisitPhoto> photosOf(PhotoLabel label) =>
      photos.where((p) => p.label == label);

  bool get hasPrescription => photosOf(PhotoLabel.prescription).isNotEmpty;
  bool get hasBill => photosOf(PhotoLabel.bill).isNotEmpty;

  bool has(CaptureKind kind) => switch (kind) {
    CaptureKind.prescriptionPhoto => hasPrescription,
    CaptureKind.bill => hasBill,
    CaptureKind.doctorVoice =>
      doctorAudioPath != null || doctorWords.trim().isNotEmpty,
    CaptureKind.chemistVoice =>
      chemistAudioPath != null || chemistWords.trim().isNotEmpty,
  };

  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    if (doctorName != null) 'doctorName': doctorName,
    'consent': consent,
    'doctorWords': doctorWords,
    'chemistWords': chemistWords,
    if (doctorAudioPath != null) 'doctorAudioPath': doctorAudioPath,
    if (chemistAudioPath != null) 'chemistAudioPath': chemistAudioPath,
    'photos': [for (final p in photos) p.toJson()],
  };

  factory Visit.fromJson(Map<String, Object?> j) => Visit(
    id: j['id']! as String,
    createdAt: DateTime.parse(j['createdAt']! as String),
    doctorName: j['doctorName'] as String?,
    consent: j['consent'] as bool? ?? false,
    doctorWords: j['doctorWords'] as String? ?? '',
    chemistWords: j['chemistWords'] as String? ?? '',
    doctorAudioPath: j['doctorAudioPath'] as String?,
    chemistAudioPath: j['chemistAudioPath'] as String?,
    photos: [
      for (final p in (j['photos'] as List? ?? const []))
        VisitPhoto.fromJson((p as Map).cast<String, Object?>()),
    ],
  );
}
