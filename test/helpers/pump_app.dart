import 'package:budget_manager/api/api.dart';
import 'package:budget_manager/app/app.dart';
import 'package:budget_manager/app/app_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_server.dart';

/// Pumps the whole app against [server], signed in when [loggedIn].
Future<AppServices> pumpApp(WidgetTester tester, FakeServer server,
    {bool loggedIn = false}) async {
  final store = InMemoryKeyValueStore();
  if (loggedIn) {
    store.values[SessionStore.accessTokenKey] = 'access-1';
    store.values[SessionStore.refreshTokenKey] = 'refresh-1';
  }
  final services = AppServices.create(store: store, httpClient: server.client);
  await services.settings.load();
  await services.auth.initialize();
  await tester.pumpWidget(BudgetManagerApp(services: services));
  await tester.pumpAndSettle();
  return services;
}
