import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrx/core/feedback/haptics.dart';
import 'package:rapidrx/core/l10n/app_language.dart';
import 'package:rapidrx/core/l10n/app_strings.dart';
import 'package:rapidrx/core/l10n/strings_wipe.dart';
import 'package:rapidrx/domain/mention.dart';
import 'package:rapidrx/domain/pharmacy_check.dart';
import 'package:rapidrx/domain/scheduled_medicine.dart';
import 'package:rapidrx/domain/sig.dart';
import 'package:rapidrx/features/doses/dose_log_store.dart';
import 'package:rapidrx/features/medicines/medicine_store.dart';
import 'package:rapidrx/features/sync/sync_queue.dart';
import 'package:rapidrx/features/visit/data_wipe.dart';
import 'package:rapidrx/features/visit/data_wipe_screen.dart';
import 'package:rapidrx/features/visit/visit.dart';
import 'package:rapidrx/features/wizard/wizard_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_haptics.dart';
import 'support/golden_harness.dart';
import 'support/wizard_fakes.dart';

void main() {
  final now = DateTime(2026, 9, 26, 9);

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('rxwipe');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test(
    'wipe drops raw capture and keeps the schedule, log, and note',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = MedicineStore(prefs);
      final logs = DoseLogStore(prefs);
      final queue = SyncQueue(prefs);
      final media = FakeMedia();
      final audio = File('${tmp.path}/doctor.m4a')..writeAsStringSync('voice');
      final note = File('${tmp.path}/chemist.m4a')
        ..writeAsStringSync('chemist');
      final photo = File('${tmp.path}/bill.jpg')..writeAsBytesSync([1, 2, 3]);
      final stray = File('${tmp.path}/stray.m4a')..writeAsStringSync('nope');
      final visit =
          Visit(
              id: 'v1',
              consent: true,
              doctorWords: 'Telma 40 subah, written in the note',
              chemistWords: 'one strip of Telma',
              doctorAudioPath: audio.path,
              chemistAudioPath: note.path,
              caretakerNote: 'check BP tonight',
              notePriority: NotePriority.high,
              createdAt: now,
            )
            ..photos.add(
              VisitPhoto(
                path: photo.path,
                label: PhotoLabel.bill,
                ocrText: 'TELMA 40 TAB',
              ),
            );
      visit.pharmacyResolutions.add(
        PharmacyResolution(
          kind: PharmacyIssueKind.quantity,
          medicineId: 'telma-40',
          choice: PharmacyChoice.a,
          explanation: 'course is 30 days',
          voiceNotePath: note.path,
          answeredBy: AnsweredBy.patient,
          answeredAt: now,
        ),
      );
      final medicine = ScheduledMedicine(
        id: 'telma-40',
        name: 'TELMA 40',
        sig: const Sig(slots: [DoseSlot.morning]),
        startDate: DateTime(2026, 9, 26),
        purpose: 'BP',
      );
      await store.approve(
        visitId: 'v1',
        approved: [medicine],
        at: now,
        caretakerNote: 'check BP tonight',
        notePriority: 'high',
      );
      await logs.logTaken(
        date: now,
        slot: DoseSlot.morning,
        medicineIds: const ['telma-40'],
        at: now,
      );
      await queue.add(
        SyncJob(
          id: 'alert-1',
          kind: 'alert',
          payload: {
            'to': '+919800000000',
            'body': 'Telma morning',
            'transcript': 'Telma 40 subah, written in the note',
            'audio': stray.path,
          },
          createdAt: now,
          visitId: 'v1',
        ),
      );

      await DataWipe.apply(visit: visit, media: media, queue: queue);

      expect(visit.doctorWords, isEmpty);
      expect(visit.chemistWords, isEmpty);
      expect(visit.doctorAudioPath, isNull);
      expect(visit.chemistAudioPath, isNull);
      expect(visit.photos, isEmpty);
      expect(visit.caretakerNote, 'check BP tonight');
      expect(visit.pharmacyResolutions.single.explanation, 'course is 30 days');
      expect(visit.pharmacyResolutions.single.voiceNotePath, isNull);
      expect(audio.existsSync(), isFalse);
      expect(note.existsSync(), isFalse);
      expect(photo.existsSync(), isFalse);
      expect(stray.existsSync(), isFalse);
      expect(visit.toJson().containsKey('doctorAudioPath'), isFalse);
      expect(visit.toJson()['doctorWords'], isEmpty);
      final job = queue.all().single;
      expect(job.payload['body'], 'Telma morning');
      expect(job.payload.containsKey('transcript'), isFalse);
      expect(job.payload.containsKey('audio'), isFalse);
      expect(store.active().single.name, 'TELMA 40');
      expect(store.records().single.caretakerNote, 'check BP tonight');
      expect(logs.all().single.taken, ['telma-40']);
    },
  );

  test(
    'a clip a queued job still needs stays until that flag is cleared',
    () async {
      SharedPreferences.setMockInitialValues({});
      final queue = SyncQueue(await SharedPreferences.getInstance());
      final media = FakeMedia();
      final audio = File('${tmp.path}/doctor.m4a')..writeAsStringSync('voice');
      final photo = File('${tmp.path}/rx.jpg')..writeAsBytesSync([4, 5, 6]);
      final visit =
          Visit(
              id: 'v1',
              consent: true,
              doctorWords: 'Telma 40 subah',
              doctorAudioPath: audio.path,
              createdAt: now,
            )
            ..photos.add(
              VisitPhoto(
                path: photo.path,
                label: PhotoLabel.prescription,
                ocrText: 'Tab Telma 40 1-0-1',
              ),
            );
      await queue.add(
        SyncJob(
          id: 'clip',
          kind: 'clip',
          payload: {
            'needsAudio': true,
            'audio': audio.path,
            'doctorWords': 'Telma 40 subah',
          },
          createdAt: now,
          visitId: 'v1',
        ),
      );
      await queue.add(
        SyncJob(
          id: 'gemini-v1',
          kind: 'gemini',
          payload: {
            'photos': [photo.path],
            'transcript': 'Tab Telma 40 1-0-1',
          },
          createdAt: now,
          visitId: 'v1',
        ),
      );

      await DataWipe.apply(visit: visit, media: media, queue: queue);

      expect(audio.existsSync(), isTrue);
      expect(photo.existsSync(), isTrue);
      expect(visit.doctorAudioPath, audio.path);
      expect(visit.photos.single.path, photo.path);
      expect(visit.photos.single.ocrText, isNull);
      expect(visit.doctorWords, isEmpty);
      final clip = queue.all().singleWhere((j) => j.id == 'clip');
      expect(clip.payload['audio'], audio.path);
      expect(clip.payload.containsKey('doctorWords'), isFalse);
      final gemini = queue.all().singleWhere((j) => j.id == 'gemini-v1');
      expect(gemini.payload['photos'], [photo.path]);
      expect(gemini.payload.containsKey('transcript'), isFalse);

      await queue.add(
        SyncJob(
          id: 'clip',
          kind: 'clip',
          payload: const {'needsAudio': false},
          createdAt: now,
          visitId: 'v1',
        ),
      );
      await queue.add(
        SyncJob(
          id: 'gemini-v1',
          kind: 'done',
          payload: const {},
          createdAt: now,
          visitId: 'v1',
        ),
      );
      await DataWipe.apply(visit: visit, media: media, queue: queue);

      expect(audio.existsSync(), isFalse);
      expect(photo.existsSync(), isFalse);
      expect(visit.doctorAudioPath, isNull);
      expect(visit.photos, isEmpty);
    },
  );

  test('approve wipes the visit and keeps the saved prescription', () async {
    final audio = File('${tmp.path}/doctor.m4a')..writeAsStringSync('voice');
    final photo = File('${tmp.path}/rx.jpg')..writeAsBytesSync([7]);
    final c = await wizard();
    await c.skip();
    await c.addPhotos([XFile(photo.path)]);
    while (c.step != WizardStep.medicines) {
      c.step == WizardStep.pharmacyWords ? await c.skip() : await c.next();
    }
    for (final row in c.rows) {
      c.canConfirm(row) ? c.confirm(row) : c.leaveOut(row);
    }
    await c.next();
    c.setCaretakerNote('check BP');
    c.setWords(SourceKind.doctor, 'Telma 40 subah khane ke baad');
    c.visit.chemistWords = 'one strip';
    c.visit.doctorAudioPath = audio.path;
    expect(c.visit.photos.single.ocrText, isNotNull);

    await c.approve();

    expect(c.visit.doctorWords, isEmpty);
    expect(c.visit.chemistWords, isEmpty);
    expect(c.visit.doctorAudioPath, isNull);
    expect(c.visit.photos, isEmpty);
    expect(c.candidates.single.ocrText, isNull);
    expect(audio.existsSync(), isFalse);
    expect(photo.existsSync(), isFalse);
    expect(c.visit.caretakerNote, 'check BP');
    expect(c.store.records().single.caretakerNote, 'check BP');
    expect(c.store.active(), isNotEmpty);
    expect(c.repository.loadDraft(), isNull);
  });

  testWidgets('skip appears after the injected threshold', (tester) async {
    final haptics = FakeHaptics.install();
    var done = false;
    await tester.pumpWidget(
      themed(
        DataWipeScreen(
          transcript: 'Telma 40 subah',
          duration: const Duration(seconds: 30),
          skipAfter: const Duration(seconds: 1),
          onDone: () => done = true,
        ),
      ),
    );
    expect(find.text('Skip'), findsNothing);
    expect(find.text(AppStrings(AppLanguage.en).wipeLine), findsOneWidget);
    expect(haptics.calls, [HapticKind.tap]);
    expect(done, isFalse);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(done, isTrue);
    expect(haptics.calls, [HapticKind.tap, HapticKind.tap]);
  });

  testWidgets('skip is ready immediately when the threshold is zero', (
    tester,
  ) async {
    var done = false;
    await tester.pumpWidget(
      themed(
        DataWipeScreen(
          duration: const Duration(seconds: 30),
          skipAfter: Duration.zero,
          onDone: () => done = true,
        ),
        language: AppLanguage.hi,
      ),
    );
    expect(find.text('छोड़ें'), findsOneWidget);
    expect(find.text(AppStrings(AppLanguage.hi).wipeLine), findsOneWidget);
    expect(done, isFalse);
    await tester.tap(find.text('छोड़ें'));
    await tester.pump();
    expect(done, isTrue);
  });
}
