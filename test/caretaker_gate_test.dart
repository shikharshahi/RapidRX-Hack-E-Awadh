import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrx/core/l10n/app_language.dart';
import 'package:rapidrx/core/l10n/app_strings.dart';
import 'package:rapidrx/core/l10n/strings_caretaker.dart';
import 'package:rapidrx/core/storage/app_prefs.dart';
import 'package:rapidrx/domain/scheduled_medicine.dart';
import 'package:rapidrx/domain/sig.dart';
import 'package:rapidrx/features/caregiver/caregiver_home.dart';
import 'package:rapidrx/features/caregiver/family_brief.dart';
import 'package:rapidrx/features/caregiver/view_gate.dart';
import 'package:rapidrx/features/doses/dose_log_store.dart';
import 'package:rapidrx/features/medicines/medicine_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/golden_harness.dart';

const en = AppStrings(AppLanguage.en);

final now = DateTime(2026, 9, 26, 10, 30);

Future<AppPrefs> prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return AppPrefs.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ViewGate', () {
    final hash = AppPrefs.hashPin('1234');

    test('family is never asked', () async {
      final gate = ViewGate(
        await prefs({'caretaker_type': 'family'}),
        clock: () => now,
      );
      expect(gate.required, isFalse);
      expect(gate.isOpen, isTrue);
    });

    test('the right PIN opens this visit only', () async {
      final stored = await prefs({
        'caretaker_type': 'commercial',
        'caretaker_view_pin_hash': hash,
      });
      final gate = ViewGate(stored, clock: () => now);
      expect(await gate.submit('0000'), GateAttempt.wrong);
      expect(gate.isOpen, isFalse);
      expect(await gate.submit('1234'), GateAttempt.opened);
      expect(gate.isOpen, isTrue);
      expect(stored.caretakerViewPinFails, 0);

      final again = ViewGate(stored, clock: () => now);
      expect(again.isOpen, isFalse);
    });

    test('five wrong tries lock the gate for five minutes', () async {
      var clock = now;
      final stored = await prefs({
        'caretaker_type': 'commercial',
        'caretaker_view_pin_hash': hash,
      });
      final gate = ViewGate(stored, clock: () => clock);
      for (var i = 0; i < 4; i++) {
        expect(await gate.submit('0000'), GateAttempt.wrong);
      }
      expect(await gate.submit('9999'), GateAttempt.locked);
      expect(await gate.submit('1234'), GateAttempt.locked);
      expect(gate.minutesLeft(), 5);

      clock = now.add(const Duration(minutes: 5));
      expect(gate.isLocked(), isFalse);
      expect(await gate.submit('1234'), GateAttempt.opened);
    });

    test('no hash yet refuses the PIN until the message is pasted', () async {
      final stored = await prefs({'caretaker_type': 'commercial'});
      final gate = ViewGate(stored, clock: () => now);
      expect(await gate.submit('1234'), GateAttempt.noHash);
      expect(await gate.acceptMessage('hello'), isFalse);
      final message = en.pairingWhatsApp('Ramesh', '4821', pinHash: hash);
      expect(await gate.acceptMessage(message), isTrue);
      expect(await gate.submit('1234'), GateAttempt.opened);
    });
  });

  group('FamilyBrief', () {
    test(
      'a morning not logged by 10:30 is missed, and a new visit shows',
      () async {
        SharedPreferences.setMockInitialValues({});
        final store = await MedicineStore.load();
        final logs = await DoseLogStore.load();
        final telma = ScheduledMedicine(
          id: 'telma-40',
          name: 'TELMA 40',
          sig: const Sig(slots: [DoseSlot.morning]),
          startDate: now,
        );
        await store.approve(visitId: 'v1', approved: [telma], at: now);
        final missed = FamilyBrief.missed(
          now: now,
          medicines: store.active(),
          logs: logs,
        );
        expect(missed, hasLength(1));
        expect(missed.single.slot, DoseSlot.morning);
        expect(FamilyBrief.recent(store.records(), now), hasLength(1));
      },
    );
  });

  group('paid caretaker home', () {
    Future<void> pump(
      WidgetTester tester, {
      required AppLanguage language,
      bool locked = false,
    }) async {
      usePhoneSurface(tester);
      final state = await freshState(
        language: language,
        values: {
          'user_name': 'Ramesh',
          'caretaker_type': 'commercial',
          'caretaker_view_pin_hash': AppPrefs.hashPin('1234'),
          if (locked)
            'caretaker_view_pin_locked_until': now
                .add(const Duration(minutes: 5))
                .millisecondsSinceEpoch,
        },
      );
      final store = await MedicineStore.load();
      final logs = await DoseLogStore.load();
      await tester.pumpWidget(
        themed(
          CaregiverHome(
            onRestart: () {},
            store: store,
            logs: logs,
            clock: () => now,
          ),
          language: language,
          state: state,
        ),
      );
      await precacheLogo(tester);
    }

    testWidgets('the PIN screen, English', (t) async {
      await pump(t, language: AppLanguage.en);
      final s = AppStrings(AppLanguage.en);
      expect(find.text(s.todaysDoses), findsNothing);
      expect(find.text(s.viewPinWhy), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/caregiver_pin_en.png'),
      );
    });

    testWidgets('the PIN screen, Hindi', (t) async {
      await pump(t, language: AppLanguage.hi);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/caregiver_pin_hi.png'),
      );
    });

    testWidgets('the right PIN shows doses and notes, not the alert tools', (
      t,
    ) async {
      await pump(t, language: AppLanguage.en);
      await t.enterText(find.byType(TextField), '1234');
      await t.tap(find.text(en.continueLabel));
      await t.pump();
      expect(find.text(en.todaysDoses), findsOneWidget);
      expect(find.text(en.alerts), findsNothing);
      expect(find.text(en.sharePlan), findsNothing);
    });

    testWidgets('a lock shows the wait, and the doses stay hidden', (t) async {
      await pump(t, language: AppLanguage.en, locked: true);
      expect(find.text(en.viewPinLocked(5)), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, en.continueLabel),
        findsOneWidget,
      );
      final button = t.widget<FilledButton>(
        find.widgetWithText(FilledButton, en.continueLabel),
      );
      expect(button.onPressed, isNull);
      expect(find.text(en.todaysDoses), findsNothing);
    });
  });
}
