import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrx/core/theme/app_theme.dart';
import 'package:rapidrx/core/widgets/rx_logo.dart';

/// Every golden is a real phone: 412 x 892 logical pixels.
const phoneSize = Size(412, 892);

/// Size the test surface to a phone, and put it back afterwards.
void usePhoneSurface(WidgetTester tester, {Size size = phoneSize}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Wrap a screen in the same theme the app uses.
Widget themed(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    home: child,
  );
}

/// Asset images decode on a real thread, which fake async never gives them.
/// Decode the logo up front so it is in the golden rather than a blank square.
Future<void> precacheLogo(WidgetTester tester) async {
  await tester.runAsync(() async {
    final context = tester.element(find.byType(Scaffold).first);
    await precacheImage(const AssetImage(RxLogo.asset), context);
  });
  await tester.pump();
}
