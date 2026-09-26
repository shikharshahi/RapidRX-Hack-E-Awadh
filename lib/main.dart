import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/phone_shell.dart';
import 'features/onboarding/role_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RapidRxApp());
}

class RapidRxApp extends StatelessWidget {
  const RapidRxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RapidRX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) => PhoneShell(child: child!),
      home: RoleScreen(onChosen: (_) {}),
    );
  }
}
