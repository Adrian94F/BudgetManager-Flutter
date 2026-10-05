import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../state/month_controller.dart';
import '../state/settings_controller.dart';
import '../tools/formatters.dart';
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
        builder: (context, _) {
          // Wallpaper colour on Android 12+ when enabled; indigo otherwise.
          final seed = services.settings.useDynamicColor ? services.dynamicSeedColor : null;
          return MaterialApp(
            title: 'Budget Manager',
            navigatorKey: _navigatorKey,
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: SettingsController.supportedLocales,
            locale: services.settings.locale,
            theme: buildTheme(Brightness.light, seedColor: seed),
            darkTheme: buildTheme(Brightness.dark, seedColor: seed),
            themeMode: services.settings.themeMode,
            // Above the navigator, so every route formats amounts in the
            // user's currency and follows a change made in the settings.
            builder: (context, child) => _CurrencyScopeHost(months: services.months, child: child!),
            home: Builder(
              builder: (context) {
                // Transparent system bars with icons readable on the theme.
                final light = Theme.of(context).brightness == Brightness.light;
                final icons = light ? Brightness.dark : Brightness.light;
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: icons,
                    systemNavigationBarColor: Colors.transparent,
                    systemNavigationBarIconBrightness: icons,
                    systemNavigationBarContrastEnforced: false,
                  ),
                  child: ListenableBuilder(
                    listenable: services.auth,
                    builder: (context, _) => services.auth.isLoggedIn ? const HomeScreen() : const LoginScreen(),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Publishes the controller's currency as a [CurrencyScope]. Only a change
/// of currency rebuilds the tree below; a notification can arrive while a
/// descendant builds (the first load starts in HomeScreen.initState), so the
/// rebuild then waits for the frame to finish.
class _CurrencyScopeHost extends StatefulWidget {
  const _CurrencyScopeHost({required this.months, required this.child});

  final MonthController months;
  final Widget child;

  @override
  State<_CurrencyScopeHost> createState() => _CurrencyScopeHostState();
}

class _CurrencyScopeHostState extends State<_CurrencyScopeHost> {
  late String _currency = widget.months.currency;

  @override
  void initState() {
    super.initState();
    widget.months.addListener(_onMonthsChanged);
  }

  @override
  void didUpdateWidget(covariant _CurrencyScopeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.months != widget.months) {
      oldWidget.months.removeListener(_onMonthsChanged);
      widget.months.addListener(_onMonthsChanged);
      _currency = widget.months.currency;
    }
  }

  @override
  void dispose() {
    widget.months.removeListener(_onMonthsChanged);
    super.dispose();
  }

  void _onMonthsChanged() {
    if (!mounted || widget.months.currency == _currency) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _onMonthsChanged());
      return;
    }
    setState(() => _currency = widget.months.currency);
  }

  @override
  Widget build(BuildContext context) => CurrencyScope(currency: _currency, child: widget.child);
}
