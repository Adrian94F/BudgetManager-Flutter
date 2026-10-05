import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../views/home.dart';
import '../views/login.dart';
import 'app_scope.dart';
import 'theme.dart';

class BudgetManagerApp extends StatefulWidget {
  const BudgetManagerApp({super.key, required this.services});

  final AppServices services;

  @override
  State<BudgetManagerApp> createState() => _BudgetManagerAppState();
}

class _BudgetManagerAppState extends State<BudgetManagerApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    widget.services.auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.services.auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// The root shows the login page once signed out; pushed screens (a form,
  /// the settings) would otherwise stay on top of it.
  void _onAuthChanged() {
    if (!widget.services.auth.isLoggedIn) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return AppScope(
      services: services,
      child: ListenableBuilder(
        listenable: services.settings,
        builder: (context, _) => MaterialApp(
          title: 'Budget Manager',
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('pl')],
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: services.settings.themeMode,
          home: ListenableBuilder(
            listenable: services.auth,
            builder: (context, _) => services.auth.isLoggedIn ? const HomeScreen() : const LoginScreen(),
          ),
        ),
      ),
    );
  }
}
