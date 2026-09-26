import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrx/core/l10n/app_language.dart';
import 'package:rapidrx/core/storage/app_prefs.dart';
import 'package:rapidrx/features/records/record_check_screen.dart';
import 'package:rapidrx/features/records/record_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/golden_harness.dart';

void main() {
  testWidgets('record check en', (tester) async {
    await _golden(tester, AppLanguage.en, 'onboarding_record_check_en');
  });

  testWidgets('record check hi', (tester) async {
    await _golden(tester, AppLanguage.hi, 'onboarding_record_check_hi');
  });
}

Future<void> _golden(WidgetTester tester, AppLanguage lead, String name) async {
  usePhoneSurface(tester);
  SharedPreferences.setMockInitialValues({});
  final prefs = await AppPrefs.load();
  await tester.pumpWidget(
    themed(
      RecordCheckScreen(
        lead: lead,
        duration: const Duration(hours: 1),
        checker: RecordChecker(prefs: prefs),
        onContinue: () {},
        onDemo: () {},
      ),
    ),
  );
  await precacheLogo(tester);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
  await tester.pumpWidget(const SizedBox());
}
