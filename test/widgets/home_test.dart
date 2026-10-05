import 'package:budget_manager/tools/dates.dart';
import 'package:budget_manager/views/month_picker_sheet.dart';
import 'package:budget_manager/views/widgets/info_card.dart';
import 'package:budget_manager/views/widgets/month_burndown_chart.dart';
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

  testWidgets('in landscape the chart fills its column and the sums keep to the right edge', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    // The 800x600 surface is landscape: chart on the left, cards on the right.
    final chart = find.byType(MonthBurndownChart);
    expect(chart, findsOneWidget);
    expect(tester.getSize(chart).height, greaterThan(350));
    expect(find.ancestor(of: chart, matching: find.byType(ListView)), findsNothing);

    // The card's amount ends where the card's padding begins (16 inside the
    // Card's own 4 dp margin), however wide the card.
    final expensesCard = find.widgetWithText(InfoCard, 'EXPENSES');
    final amount = find.descendant(of: expensesCard, matching: find.byType(FittedBox));
    expect(tester.getTopRight(amount).dx, closeTo(tester.getTopRight(expensesCard).dx - 20, 1));
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

  testWidgets('pull-to-refresh reloads the month', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);
    final loadsBefore = server.monthLoads;

    await tester.drag(find.text('BALANCE'), const Offset(0, 300));
    await tester.pump();
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(server.monthLoads, loadsBefore + 1);
  });

  testWidgets('tapping the selected destination again reloads the month', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);
    final loadsBefore = server.monthLoads;

    // The test surface is 800 px wide, so navigation is the rail.
    final incomesDestination = find.descendant(of: find.byType(NavigationRail), matching: find.text('Incomes'));

    // Another destination: no reload, just the tab.
    await tester.tap(incomesDestination);
    await tester.pumpAndSettle();
    expect(find.text('No incomes yet.'), findsNothing);
    expect(server.monthLoads, loadsBefore);

    // The same one again: back to the top and a reload.
    await tester.tap(incomesDestination);
    await tester.pumpAndSettle();
    expect(server.monthLoads, loadsBefore + 1);
  });

  testWidgets('a phone in landscape gets a compact bar, rail actions and a menu that fits', (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    // One-line bar with the date range beside the name, no large title.
    expect(tester.widget<SliverAppBar>(find.byType(SliverAppBar)).expandedHeight, isNull);
    final range = server.currentMonth['start_date'] as String;
    expect(find.textContaining(Dates.parseApi(range).day.toString()), findsWidgets);

    // Month picker and Settings live in the rail, not in the bar.
    final rail = find.byType(NavigationRail);
    expect(find.descendant(of: rail, matching: find.byTooltip('Select month')), findsOneWidget);
    expect(find.descendant(of: rail, matching: find.byTooltip('Settings')), findsOneWidget);
    expect(find.descendant(of: find.byType(SliverAppBar), matching: find.byTooltip('Settings')), findsNothing);
    // 360 dp leaves room for the selected destination's label only, and none
    // under the two actions.
    expect(tester.widget<NavigationRail>(rail).labelType, NavigationRailLabelType.selected);
    expect(find.descendant(of: rail, matching: find.text('Settings')), findsNothing);

    // The summary's action sheet shows every action without overflowing.
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Add expense'), findsOneWidget);
    expect(find.text('Create new'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tall window labels every rail item, the actions included', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    final rail = find.byType(NavigationRail);
    expect(tester.widget<NavigationRail>(rail).labelType, NavigationRailLabelType.all);
    expect(find.descendant(of: rail, matching: find.text('Month')), findsOneWidget);
    expect(find.descendant(of: rail, matching: find.text('Settings')), findsOneWidget);

    await tester.tap(find.descendant(of: rail, matching: find.text('Month')));
    await tester.pumpAndSettle();
    expect(find.byType(MonthPickerSheet), findsOneWidget);
  });

  testWidgets('opens Settings from the top bar', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('App settings'), findsOneWidget);
    expect(find.text('Budget settings'), findsOneWidget);
    // Categories belong to the budget, so they sit under Budget settings.
    expect(find.text('Manage categories'), findsNothing);
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

  testWidgets('Budget settings counts the categories and opens their list', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Budget settings'));
    await tester.pumpAndSettle();

    final categoriesTile = find.widgetWithText(ListTile, 'Categories');
    expect(find.descendant(of: categoriesTile, matching: find.text('2')), findsOneWidget);

    await tester.tap(categoriesTile);
    await tester.pumpAndSettle();
    expect(find.text('Manage categories'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
  });

  testWidgets('changes the currency from Budget settings', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);
    expect(find.textContaining('zł'), findsWidgets);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Budget settings'));
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
