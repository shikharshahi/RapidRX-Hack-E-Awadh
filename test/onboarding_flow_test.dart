import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrx/app.dart';
import 'package:rapidrx/core/storage/app_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/golden_harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppPrefs> prefs() => AppPrefs.load();

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String value) async {
    await tester.enterText(find.byType(TextField).first, value);
    await tester.pump();
  }

  testWidgets('walks the whole onboarding chain in Hindi to the patient menu', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final p = await prefs();
    await tester.pumpWidget(
      RapidRxApp(
        prefs: p,
        showSplash: false,
        stageDelay: const Duration(milliseconds: 10),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('हिंदी'));
    await tester.pump();
    await tester.pump();
    expect(p.language?.code, 'hi');
    // The saving screen is already in Hindi.
    expect(find.text('आपकी पसंद सेव हो रही है…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    await tapText(tester, 'नहीं');
    expect(p.voiceHelp, isFalse);

    await enter(tester, '9876543210');
    await tapText(tester, 'आगे बढ़ें');
    await enter(tester, '1234');
    await tapText(tester, 'जाँचें');
    expect(p.phoneNumber, '9876543210');

    await enter(tester, 'Ramesh');
    await tapText(tester, 'आगे बढ़ें');
    expect(p.name, 'Ramesh');
    expect(p.backupPhone, isNull);

    await enter(tester, '4321');
    await tapText(tester, 'आगे बढ़ें');
    await enter(tester, '4321');
    await tapText(tester, 'आगे बढ़ें');
    expect(p.hasPin, isTrue);
    expect(p.checkPin('4321'), isTrue);

    await tapText(tester, 'मरीज़');
    expect(p.role, AppRole.patient);
    expect(find.text('नई पर्ची'), findsOneWidget);
    // Let the saving screen timer drain.
    await tester.pump(const Duration(milliseconds: 20));
  });

  testWidgets('a mismatched PIN sends the user back to set it again', (
    tester,
  ) async {
    usePhoneSurface(tester);
    SharedPreferences.setMockInitialValues({
      'app_language': 'en',
      'voice_help': false,
      'phone_number': '9876543210',
      'user_name': 'Ramesh',
    });
    final p = await prefs();
    await tester.pumpWidget(RapidRxApp(prefs: p, showSplash: false));
    await tester.pump();
    // DevFlags.alwaysShowOnboarding starts at language; walk forward.
    if (find.text('ENGLISH').evaluate().isNotEmpty) {
      await tapText(tester, 'ENGLISH');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tapText(tester, 'No');
      await enter(tester, '9876543210');
      await tapText(tester, 'Continue');
      await enter(tester, '1234');
      await tapText(tester, 'Verify');
      await tapText(tester, 'Continue');
    }

    await enter(tester, '1111');
    await tapText(tester, 'Continue');
    await enter(tester, '2222');
    await tapText(tester, 'Continue');

    expect(p.hasPin, isFalse);
    expect(find.text('Set a 4-digit PIN'), findsWidgets);
    expect(
      find.text('The two PINs are different. Set it again.'),
      findsOneWidget,
    );
  });

  testWidgets('a family number gets its own code check', (tester) async {
    usePhoneSurface(tester);
    SharedPreferences.setMockInitialValues({
      'app_language': 'en',
      'voice_help': false,
      'phone_number': '9876543210',
    });
    final p = await prefs();
    await tester.pumpWidget(RapidRxApp(prefs: p, showSplash: false));
    await tester.pump();
    if (find.text('ENGLISH').evaluate().isNotEmpty) {
      await tapText(tester, 'ENGLISH');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tapText(tester, 'No');
      await enter(tester, '9876543210');
      await tapText(tester, 'Continue');
      await enter(tester, '1234');
      await tapText(tester, 'Verify');
    }

    await tester.enterText(find.byType(TextField).at(0), 'Ramesh');
    await tester.enterText(find.byType(TextField).at(1), '9812345678');
    await tapText(tester, 'Continue');

    expect(find.text('Code for your family member'), findsOneWidget);
    expect(p.backupPhone, isNull, reason: 'not saved until verified');
    await enter(tester, '1234');
    await tapText(tester, 'Verify');
    expect(p.backupPhone, '9812345678');
  });

  test('the PIN is stored as a hash, never as itself', () async {
    final p = await prefs();
    await p.setPin('4321');
    final raw = (await SharedPreferences.getInstance()).getString('pin_hash');
    expect(raw, isNot(contains('4321')));
    expect(raw, hasLength(64));
    expect(p.checkPin('4321'), isTrue);
    expect(p.checkPin('1234'), isFalse);
  });
}
