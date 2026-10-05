import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = AppServices.create();
  // Settings and the stored session are read before the first frame, so the
  // native splash screen stays up instead of an in-app spinner.
  await Future.wait([services.settings.load(), services.auth.initialize()]);
  runApp(BudgetManagerApp(services: services));
}
