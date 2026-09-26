import 'package:flutter/material.dart';

import 'app.dart';
import 'core/storage/app_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await AppPrefs.load();
  runApp(RapidRxApp(prefs: prefs));
}
