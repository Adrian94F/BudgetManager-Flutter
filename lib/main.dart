import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/app_scope.dart';
import 'app/dynamic_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind both system bars on every Android version (API 35+ does so
  // by default) and keep the bars transparent; the screens handle the insets.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));
  final services = AppServices.create();
  // Settings, the stored session and the system colour are read before the
  // first frame, so the native splash screen stays up instead of an in-app
  // spinner.
  await Future.wait([
    services.settings.load(),
    services.auth.initialize(),
    loadDynamicSeedColor().then((seed) => services.dynamicSeedColor = seed),
  ]);
  runApp(BudgetManagerApp(services: services));
}
