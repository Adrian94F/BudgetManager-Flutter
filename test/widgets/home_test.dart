import 'package:budget_manager/tools/dates.dart';
import 'package:budget_manager/views/month_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../helpers/fake_server.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('loads the current month and shows its figures', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    final title = DateFormat.MMMM('en').format(Dates.parseApi(server.currentMonth['start_date'] as String));
    expect(find.text(title), findsOneWidget);
    expect(find.text('BALANCE'), findsOneWidget);
    // 5000 income - 120 expense
    expect(find.textContaining('4,880.00'), findsOneWidget);
  });

  testWidgets('switches months through the picker', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);
    final previous = server.months.firstWhere((m) => m['id'] == 10);
    final previousTitle = DateFormat.MMMM('en').format(Dates.parseApi(previous['start_date'] as String));

    await tester.tap(find.byTooltip('Select month'));
    await tester.pumpAndSettle();
    expect(find.text('Select month'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.descendant(of: find.byType(MonthPickerSheet), matching: find.byType(ListTile)), findsNWidgets(2));

    await tester.tap(find.descendant(of: find.byType(MonthPickerSheet), matching: find.text(previousTitle)));
    await tester.pumpAndSettle();

    expect(server.requests.last.url.queryParameters['month_id'], '10');
    expect(find.text(previousTitle), findsOneWidget);
    expect(find.byType(MonthPickerSheet), findsNothing);
  });

  testWidgets('swipes to the previous month on the Summary', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);
    final previous = server.months.firstWhere((m) => m['id'] == 10);
    final previousTitle = DateFormat.MMMM('en').format(Dates.parseApi(previous['start_date'] as String));

    await tester.fling(find.text('BALANCE'), const Offset(400, 0), 1200);
    await tester.pumpAndSettle();

    expect(server.requests.last.url.queryParameters['month_id'], '10');
    expect(find.text(previousTitle), findsOneWidget);

    // Back to the newer month with a fling to the left.
    await tester.fling(find.text('BALANCE'), const Offset(-400, 0), 1200);
    await tester.pumpAndSettle();
    expect(server.requests.last.url.queryParameters['month_id'], '11');
  });

  testWidgets('opens Settings from the top bar', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('App settings'), findsOneWidget);
    expect(find.text('Manage categories'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
  });

  testWidgets('changes the language from App settings', (tester) async {
    final server = FakeServer();
    final services = await pumpApp(tester, server, loggedIn: true);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('App settings'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);

    await tester.tap(find.text('Polski'));
    await tester.pumpAndSettle();

    expect(services.settings.locale, const Locale('pl'));
    expect(await services.session.locale(), 'pl');
    expect(find.text('Ustawienia aplikacji'), findsOneWidget);
    expect(find.text('Język'), findsOneWidget);

    await tester.tap(find.text('Jak w systemie'));
    await tester.pumpAndSettle();
    expect(services.settings.locale, isNull);
    expect(find.text('App settings'), findsOneWidget);
  });

  testWidgets('changes the currency from App settings', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);
    expect(find.textContaining('zł'), findsWidgets);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('App settings'));
    await tester.pumpAndSettle();
    expect(find.text('PLN · zł'), findsOneWidget);

    await tester.tap(find.text('Currency'));
    await tester.pumpAndSettle();
    expect(find.text('Choose currency'), findsOneWidget);
    await tester.tap(find.text('Euro'));
    await tester.pumpAndSettle();

    expect(server.currency, 'EUR');
    expect(find.text('Currency changed'), findsOneWidget);
    expect(find.text('EUR · €'), findsOneWidget);

    // Back on the summary every amount is in euro, without a reload.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('€4,880.00'), findsOneWidget);
    expect(find.textContaining('zł'), findsNothing);
  });

  testWidgets('keeps the data and shows a banner when a refresh fails', (tester) async {
    final server = FakeServer();
    final services = await pumpApp(tester, server, loggedIn: true);

    server.defaultMonthId = 99; // the server now answers 500 for the default month
    services.months.data; // data stays
    await services.months.load();
    await tester.pumpAndSettle();

    expect(find.text('BALANCE'), findsOneWidget);
    expect(find.textContaining("Couldn't load data."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
