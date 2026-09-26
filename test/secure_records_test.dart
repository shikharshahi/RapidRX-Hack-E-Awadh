import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrx/app.dart';
import 'package:rapidrx/core/feedback/haptics.dart';
import 'package:rapidrx/core/l10n/app_strings.dart';
import 'package:rapidrx/core/storage/app_prefs.dart';
import 'package:rapidrx/domain/scheduled_medicine.dart';
import 'package:rapidrx/domain/sig.dart';
import 'package:rapidrx/features/doses/dose_log_store.dart';
import 'package:rapidrx/features/medicines/medicine_store.dart';
import 'package:rapidrx/features/records/demo_records.dart';
import 'package:rapidrx/features/records/record_checker.dart';
import 'package:rapidrx/features/records/record_ports.dart';
import 'package:rapidrx/features/records/secure_record_store.dart';
import 'package:rapidrx/features/visit/visit.dart';
import 'package:rapidrx/features/visit/visit_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/golden_harness.dart';

const _kdf = 50;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SecureRecordStore.debugReset();
    RecordHooks.reset();
    Haptics.debugOverride = (_) {};
  });

  tearDown(() {
    SecureRecordStore.debugReset();
    RecordHooks.reset();
    Haptics.debugOverride = null;
  });

  Future<SecureRecordStore> open({
    SharedPreferences? prefs,
    KeyBox? keyBox,
    RecordFile? file,
    BackupSink? backup,
    DateTime Function()? clock,
  }) async {
    return SecureRecordStore.open(
      prefs: prefs ?? await SharedPreferences.getInstance(),
      keyBox: keyBox ?? MemoryKeyBox(),
      file: file ?? MemoryRecordFile(),
      backup: backup ?? MemoryBackupSink(),
      kdfIterations: _kdf,
      clock: clock,
    );
  }

  group('vault', () {
    test(
      'encrypt and decrypt round-trip, with a new nonce each write',
      () async {
        final file = MemoryRecordFile();
        final sink = MemoryBackupSink();
        final store = await open(file: file, backup: sink);
        await store.write(MedicalKeys.doses, '[{"slot":"morning"}]');
        final first = jsonDecode(utf8.decode(file.value!)) as Map;
        await store.write(MedicalKeys.doses, '[{"slot":"night"}]');
        final second = jsonDecode(utf8.decode(file.value!)) as Map;
        expect(first['nonce'], isNot(second['nonce']));

        await store.rewrap('1357');
        final copy = await open(
          keyBox: MemoryKeyBox(),
          file: MemoryRecordFile(),
          backup: sink,
        );
        expect(copy.read(MedicalKeys.doses), isNull);
        expect(await copy.restore('1357'), RestoreResult.ok);
        expect(copy.read(MedicalKeys.doses), '[{"slot":"night"}]');
      },
    );

    test('a wrong PIN fails and leaves the backup', () async {
      final sink = MemoryBackupSink();
      final store = await open(backup: sink);
      await store.write(MedicalKeys.medicines, '["telma"]');
      await store.rewrap('1357');
      final before = Uint8List.fromList(sink.vault!);

      final copy = await open(
        keyBox: MemoryKeyBox(),
        file: MemoryRecordFile(),
        backup: sink,
      );
      expect(await copy.restore('0000'), RestoreResult.wrongPin);
      expect(copy.read(MedicalKeys.medicines), isNull);
      expect(sink.vault, before);
    });

    test('a tampered file is rejected', () async {
      final sink = MemoryBackupSink();
      final store = await open(backup: sink);
      await store.write(MedicalKeys.medicines, '["telma"]');
      await store.rewrap('1357');
      final env = jsonDecode(utf8.decode(sink.vault!)) as Map<String, Object?>;
      final cipher = base64Decode(env['ciphertext']! as String);
      cipher[0] ^= 0xff;
      env['ciphertext'] = base64Encode(cipher);
      sink.vault = Uint8List.fromList(utf8.encode(jsonEncode(env)));

      final copy = await open(
        keyBox: MemoryKeyBox(),
        file: MemoryRecordFile(),
        backup: sink,
      );
      expect(await copy.restore('1357'), RestoreResult.tampered);
      expect(copy.read(MedicalKeys.medicines), isNull);
    });

    test('five wrong PINs lock, and the right one works after', () async {
      final sink = MemoryBackupSink();
      final origin = await open(backup: sink);
      await origin.write(MedicalKeys.doses, '["kept"]');
      await origin.rewrap('1357');
      final sealed = await open(
        keyBox: MemoryKeyBox(),
        file: MemoryRecordFile(),
        backup: sink,
      );
      var now = DateTime(2026, 9, 26, 12);
      final checker = RecordChecker(
        prefs: await AppPrefs.load(),
        store: sealed,
        lockFor: const Duration(minutes: 5),
        clock: () => now,
      );
      for (var i = 0; i < 4; i++) {
        expect(await checker.enterPin('0000'), PinAttempt.wrong);
      }
      expect(await checker.enterPin('0000'), PinAttempt.locked);
      expect(await checker.enterPin('1357'), PinAttempt.locked);
      now = now.add(const Duration(minutes: 5));
      expect(await checker.enterPin('1357'), PinAttempt.ok);
      expect(sealed.read(MedicalKeys.doses), '["kept"]');
    });

    test('a corrupt file is left in place and the store stays empty', () async {
      final file = MemoryRecordFile()
        ..value = Uint8List.fromList(utf8.encode('{not json'));
      final store = await open(file: file);
      expect(store.fault, VaultFault.corrupt);
      expect(store.hasRecords, isFalse);
      expect(utf8.decode(file.value!), '{not json');
    });

    test('the manifest has counts and a phone hash, and no medicine', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPrefs.load();
      await prefs.setPhoneNumber('9000000001');
      final sink = MemoryBackupSink();
      final store = await open(prefs: prefs.raw, backup: sink);
      await store.write(
        MedicalKeys.medicines,
        jsonEncode([
          {'name': 'TELMA 40'},
        ]),
      );
      await store.rewrap('1357');
      final manifest = sink.manifestJson!;
      expect(manifest, contains('"v":1'));
      expect(manifest, contains('"medicines":1'));
      expect(manifest, contains('phoneHash'));
      expect(manifest, isNot(contains('TELMA')));
      expect(manifest, isNot(contains('9000000001')));
    });

    test(
      'migration copies plain medical prefs and deletes only those',
      () async {
        final med = ScheduledMedicine(
          id: 'telma-40',
          name: 'TELMA 40',
          sig: const Sig(slots: [DoseSlot.morning]),
          startDate: DateTime(2026, 9, 1),
        );
        final log = DoseLog(
          date: DateTime(2026, 9, 1),
          slot: DoseSlot.morning,
          confirmedAt: DateTime(2026, 9, 1, 8),
          taken: const ['telma-40'],
        );
        final visit = Visit(id: 'v1', createdAt: DateTime(2026, 9, 1));
        SharedPreferences.setMockInitialValues({
          'app_language': 'en',
          'pin_hash': 'keep-me',
          MedicalKeys.medicines: jsonEncode([med.toJson()]),
          MedicalKeys.records: jsonEncode([
            {
              'id': 'v1',
              'addedAt': '2026-09-01T00:00:00.000',
              'medicineNames': ['TELMA 40'],
            },
          ]),
          MedicalKeys.doses: jsonEncode([log.toJson()]),
          MedicalKeys.visit: jsonEncode(visit.toJson()),
        });
        SecureRecordStore.debugReset();

        final store = await MedicineStore.load();
        expect(store.medicines().single.name, 'TELMA 40');
        expect(store.records().single.id, 'v1');
        expect((await DoseLogStore.load()).all(), hasLength(1));
        expect((await VisitRepository.load()).loadDraft()?.id, 'v1');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(MedicalKeys.medicines), isNull);
        expect(prefs.getString(MedicalKeys.records), isNull);
        expect(prefs.getString(MedicalKeys.doses), isNull);
        expect(prefs.getString(MedicalKeys.visit), isNull);
        expect(prefs.getString('app_language'), 'en');
        expect(prefs.getString('pin_hash'), 'keep-me');
        final blob = prefs.getString('vault_blob')!;
        expect(blob, isNot(contains('TELMA')));
      },
    );
  });

  group('restore check', () {
    final now = DateTime(2026, 9, 26, 16);

    Future<AppPrefs> prefs() => AppPrefs.load();

    Widget appOf(AppPrefs p) => RapidRxApp(
      prefs: p,
      stageDelay: const Duration(milliseconds: 1),
      recordCheckDelay: const Duration(milliseconds: 1),
      enableSync: false,
    );

    Future<MemoryBackupSink> seedBackup() async {
      final sink = MemoryBackupSink();
      final p = await prefs();
      await p.setPhoneNumber('9000000001');
      final origin = await open(prefs: p.raw, backup: sink, clock: () => now);
      await MedicineStore(origin).approve(
        visitId: 'v1',
        approved: [
          ScheduledMedicine(
            id: 'telma-40',
            name: 'TELMA 40',
            sig: const Sig(slots: [DoseSlot.morning]),
            startDate: DateTime(2026, 9, 20),
          ),
        ],
        at: now,
      );
      await origin.rewrap('1357');
      RecordHooks.backup = sink;
      RecordHooks.keyBox = MemoryKeyBox();
      RecordHooks.file = MemoryRecordFile();
      RecordHooks.kdfIterations = _kdf;
      SecureRecordStore.debugReset();
      return sink;
    }

    testWidgets('found, Yes, loads the records', (tester) async {
      usePhoneSurface(tester);
      final sink = await seedBackup();
      expect(sink.manifestJson, isNot(contains('TELMA')));
      await tester.pumpWidget(appOf(await prefs()));
      await _pastSplash(tester);
      expect(
        find.text('Previous medical files found. Restore and sync them?'),
        findsOneWidget,
      );
      expect(find.textContaining('1 medicines'), findsOneWidget);

      await tester.tap(find.text('Yes · हाँ'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1357');
      await tester.tap(find.text('Continue · आगे बढ़ें'));
      await tester.pumpAndSettle();

      expect((await MedicineStore.load()).medicines().single.name, 'TELMA 40');
      expect(find.text('Do you need voice help?'), findsOneWidget);
    });

    testWidgets('found, No, leaves the file and continues', (tester) async {
      usePhoneSurface(tester);
      final sink = await seedBackup();
      final before = Uint8List.fromList(sink.vault!);
      await tester.pumpWidget(appOf(await prefs()));
      await _pastSplash(tester);
      await tester.tap(find.text('No · नहीं'));
      await tester.pumpAndSettle();

      expect(sink.vault, before);
      expect(find.text('Do you need voice help?'), findsOneWidget);
      expect((await MedicineStore.load()).medicines(), isEmpty);
    });

    testWidgets('nothing found shows the demo dialog', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(appOf(await prefs()));
      await _pastSplash(tester);
      expect(
        find.text(
          'No saved medical files on this phone. Load a sample profile?',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('2 medicines'), findsOneWidget);
    });

    testWidgets('records already on the device still ask yes or no', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final file = MemoryRecordFile();
      final keys = MemoryKeyBox();
      final sink = MemoryBackupSink();
      final p = await prefs();
      await p.setPhoneNumber('9000000001');
      final origin = await open(
        prefs: p.raw,
        file: file,
        keyBox: keys,
        backup: sink,
        clock: () => now,
      );
      await origin.write(MedicalKeys.medicines, '["telma"]');
      await origin.rewrap('1357');
      RecordHooks.file = file;
      RecordHooks.keyBox = keys;
      RecordHooks.backup = sink;
      RecordHooks.kdfIterations = _kdf;
      SecureRecordStore.debugReset();

      await tester.pumpWidget(appOf(p));
      await _pastSplash(tester);

      expect(
        find.text('Previous medical files found. Restore and sync them?'),
        findsOneWidget,
      );
      expect(find.text('Yes · हाँ'), findsOneWidget);
      expect(find.text('No · नहीं'), findsOneWidget);
    });

    testWidgets('a previous No still asks again', (tester) async {
      usePhoneSurface(tester);
      final p = await prefs();
      await p.setDemoDeclined(true);
      await tester.pumpWidget(appOf(p));
      await _pastSplash(tester);

      expect(
        find.text(
          'No saved medical files on this phone. Load a sample profile?',
        ),
        findsOneWidget,
      );
      expect(find.text('Yes · हाँ'), findsOneWidget);
      expect(find.text('No · नहीं'), findsOneWidget);
    });

    testWidgets('an injected short delay does not hang', (tester) async {
      usePhoneSurface(tester);
      final watch = Stopwatch()..start();
      await tester.pumpWidget(appOf(await prefs()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(
        find.text('Which language are you comfortable in?'),
        findsOneWidget,
      );
      await tester.tap(find.text('ENGLISH'));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Checking Your Device For Pre-Existing Medical Record'),
        findsOneWidget,
      );
      expect(find.text('Fetching Now'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(
        find.text(
          'No saved medical files on this phone. Load a sample profile?',
        ),
        findsOneWidget,
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    testWidgets('demo Yes loads the fixture', (tester) async {
      usePhoneSurface(tester);
      RecordHooks.clock = () => now;
      RecordHooks.kdfIterations = _kdf;
      await tester.pumpWidget(appOf(await prefs()));
      await _pastSplash(tester);
      await tester.tap(find.text('Yes · हाँ'));
      await tester.pumpAndSettle();

      expect(find.text('Hello Geeta Mishra'), findsOneWidget);
      expect(find.text('Clear profile'), findsNothing);
      expect(find.text('Leave demo'), findsNothing);
      final p = await prefs();
      expect(p.name, DemoRecords.name);
      expect(p.age, DemoRecords.age);
      expect(p.linkedCaretakerJson, contains('Sunita'));
      final meds = await MedicineStore.load();
      expect(meds.records(), hasLength(2));
      expect(meds.active(), hasLength(2));
      final logs = await DoseLogStore.load();
      final today = DateTime(2026, 9, 26);
      expect(logs.statusOf(now, today, DoseSlot.morning), DoseStatus.taken);
      expect(logs.statusOf(now, today, DoseSlot.afternoon), DoseStatus.missed);
      expect(logs.statusOf(now, today, DoseSlot.evening), DoseStatus.notYet);
      expect(logs.statusOf(now, today, DoseSlot.night), DoseStatus.notYet);
      final days = logs.all().map((l) => l.date).toSet();
      expect(days, hasLength(7));
    });
  });
}

Future<void> _pastSplash(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
  await tester.tap(find.text('ENGLISH'));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
}
