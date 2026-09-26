import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrx/features/onboarding/role_screen.dart';

import 'support/golden_harness.dart';

void main() {
  testWidgets('role screen', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(themed(RoleScreen(onChosen: (_) {})));
    await precacheLogo(tester);

    expect(find.text('PATIENT'), findsOneWidget);
    expect(find.text('CAREGIVER'), findsOneWidget);
    await expectLater(
      find.byType(RoleScreen),
      matchesGoldenFile('goldens/onboarding_10_role_en.png'),
    );
  });

  testWidgets('choosing a role reports it', (tester) async {
    usePhoneSurface(tester);
    AppRole? chosen;
    await tester.pumpWidget(themed(RoleScreen(onChosen: (r) => chosen = r)));
    await tester.tap(find.text('CAREGIVER'));
    expect(chosen, AppRole.caregiver);
  });
}
