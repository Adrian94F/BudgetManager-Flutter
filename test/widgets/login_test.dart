import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_server.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('shows the login page without a session and signs in',
      (tester) async {
    final server = FakeServer();
    final services = await pumpApp(tester, server);

    expect(find.text('Budget Manager'), findsOneWidget);
    expect(find.text('BALANCE'), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), 'adrian');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.text('LOGIN'));
    await tester.pumpAndSettle();

    expect(services.auth.isLoggedIn, isTrue);
    expect(find.text('BALANCE'), findsOneWidget);
    expect(server.requests.first.url.path, '/api/token/');
  });

  testWidgets('says when the credentials are wrong and stays on the page',
      (tester) async {
    final server = FakeServer();
    final services = await pumpApp(tester, server);

    await tester.enterText(find.byType(TextField).at(0), 'adrian');
    await tester.enterText(find.byType(TextField).at(1), 'nope');
    await tester.tap(find.text('LOGIN'));
    await tester.pumpAndSettle();

    expect(services.auth.isLoggedIn, isFalse);
    expect(find.text('Wrong username or password.'), findsOneWidget);
  });

  testWidgets('remembers the credentials when asked', (tester) async {
    final server = FakeServer();
    final services = await pumpApp(tester, server);

    await tester.enterText(find.byType(TextField).at(0), 'adrian');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text('LOGIN'));
    await tester.pumpAndSettle();

    expect(await services.session.savedCredentials(),
        (username: 'adrian', password: 'secret'));
  });
}
