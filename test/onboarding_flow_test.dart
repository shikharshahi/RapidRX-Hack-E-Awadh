import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrx/app.dart';
import 'package:rapidrx/core/storage/app_prefs.dart';
import 'package:rapidrx/features/health/pmjay_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/golden_harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppPrefs> prefs() => AppPrefs.load();

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String value, {int at = 0}) async {
    await tester.enterText(find.byType(TextField).at(at), value);
    await tester.pump();
  }

  Widget app(AppPrefs p, {bool resume = true}) => RapidRxApp(
    prefs: p,
    showSplash: false,
    stageDelay: const Duration(milliseconds: 10),
    pmjay: MockPmjayClient(delay: Duration.zero),
    resumeOnboarding: resume,
  );

  testWidgets('the whole chain in Hindi: … PIN → role → health → menu', (
    tester,
  ) async {
    usePhoneSurface(tester);
    final p = await prefs();
    await tester.pumpWidget(app(p));
    await tester.pump();

    await tester.tap(find.text('हिंदी'));
    await tester.pump();
    await tester.pump();
    expect(p.language?.code, 'hi');
    expect(find.text('आपकी पसंद सेव हो रही है…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    await tapText(tester, 'नहीं');
    await enter(tester, '9876543210');
    await tapText(tester, 'आगे बढ़ें');
    await enter(tester, '1234');
    await tapText(tester, 'जाँचें');

    // Name only: the family number now comes from the caretaker's QR code.
    expect(find.byType(TextField), findsOneWidget);
    await enter(tester, 'Ramesh');
    await tapText(tester, 'आगे बढ़ें');

    await enter(tester, '4321');
    await tapText(tester, 'आगे बढ़ें');
    await enter(tester, '4321');
    await tapText(tester, 'आगे बढ़ें');
    expect(p.hasPin, isTrue);

    // The role comes right after the PIN…
    expect(find.text('यह ऐप कौन चला रहा है?'), findsOneWidget);
    await tapText(tester, 'मरीज़');
    expect(p.role, AppRole.patient);

    // …and only a patient is asked about their health.
    expect(find.text('आपकी सेहत के बारे में'), findsOneWidget);
    await enter(tester, '64');
    await tapText(tester, 'आगे बढ़ें');
    expect(p.age, 64);
    expect(find.text('नई पर्ची'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 20));
  });

  testWidgets('a caretaker is not asked about health', (tester) async {
    usePhoneSurface(tester);
    SharedPreferences.setMockInitialValues({
      'app_language': 'en',
      'voice_help': false,
      'phone_number': '9876543210',
      'user_name': 'Sunita',
      'pin_hash': AppPrefs.hashPin('1111'),
    });
    final p = await prefs();
    await tester.pumpWidget(app(p));
    await tester.pumpAndSettle();
    expect(find.text('Who is using this app?'), findsOneWidget);
    await tapText(tester, 'CAREGIVER');
    expect(find.text('A little about your health'), findsNothing);
    expect(p.age, isNull);
  });

  group('resume', () {
    final base = <String, Object>{
      'app_language': 'en',
      'voice_help': false,
      'phone_number': '9876543210',
      'user_name': 'Ramesh',
      'pin_hash': AppPrefs.hashPin('1111'),
    };

    Future<void> resumeAt(
      WidgetTester tester,
      Map<String, Object> values,
      String expected,
    ) async {
      usePhoneSurface(tester);
      SharedPreferences.setMockInitialValues(values);
      await tester.pumpWidget(app(await prefs()));
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget);
    }

    testWidgets('no name yet → the name screen', (t) async {
      await resumeAt(t, {...base}..remove('user_name'), 'About you');
    });

    testWidgets('no PIN yet → the PIN screen', (t) async {
      // The title and the field hint both say it.
      await resumeAt(
        t,
        {...base}..remove('pin_hash'),
        'You will use it to open RapidRX. Choose something you will remember.',
      );
    });

    testWidgets('no role yet → the role screen', (t) async {
      await resumeAt(t, base, 'Who is using this app?');
    });

    testWidgets('a patient with no age → the health screen', (t) async {
      await resumeAt(t, {
        ...base,
        'app_role': 'patient',
      }, 'A little about your health');
    });

    testWidgets('everything done → the menu', (t) async {
      await resumeAt(t, {
        ...base,
        'app_role': 'patient',
        'health_age': 64,
      }, 'What would you like to do?');
    });
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
    await tester.pumpWidget(app(p));
    await tester.pumpAndSettle();

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

  test('the PIN is stored as a hash, never as itself', () async {
    final p = await prefs();
    await p.setPin('4321');
    final raw = (await SharedPreferences.getInstance()).getString('pin_hash');
    expect(raw, isNot(contains('4321')));
    expect(raw, hasLength(64));
    expect(p.checkPin('4321'), isTrue);
    expect(p.checkPin('1234'), isFalse);
  });

  test('forgetting who this is also forgets their health', () async {
    final p = await prefs();
    await p.setHealth(age: 64, heightCm: 165, ayushmanId: 'PMJ4K7Q2X');
    await p.clearIdentity();
    expect(p.age, isNull);
    expect(p.heightCm, isNull);
    expect(p.ayushmanId, isNull);
  });
}
