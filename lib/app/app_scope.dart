import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../api/api.dart';
import '../state/auth_controller.dart';
import '../state/month_controller.dart';
import '../state/settings_controller.dart';

/// The app's long-lived objects, wired together once at startup.
class AppServices {
  AppServices({
    required this.session,
    required this.api,
    required this.auth,
    required this.settings,
    required this.months,
  });

  final SessionStore session;
  final ApiClient api;
  final AuthController auth;
  final SettingsController settings;
  final MonthController months;

  /// Production wiring; tests pass an in-memory [store] and a mock [httpClient].
  factory AppServices.create({KeyValueStore? store, http.Client? httpClient}) {
    final session = SessionStore(store ?? const SecureKeyValueStore());
    late final AuthController auth;
    final api = ApiClient(
      session: session,
      httpClient: httpClient,
      onSessionExpired: () => auth.markSessionExpired(),
    );
    auth = AuthController(api: api, session: session);
    final settings = SettingsController(session);
    final months = MonthController(api);
    auth.addListener(() {
      if (!auth.isLoggedIn) months.clear();
    });
    return AppServices(session: session, api: api, auth: auth, settings: settings, months: months);
  }
}

/// Makes [AppServices] available to the widget tree. Widgets subscribe to a
/// controller with a `ListenableBuilder`; the scope itself never notifies.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
