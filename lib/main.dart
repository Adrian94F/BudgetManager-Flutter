import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_scope.dart';
import 'app/dynamic_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
