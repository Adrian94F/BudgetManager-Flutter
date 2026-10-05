import 'package:budget_manager/domain/domain.dart';
import 'package:budget_manager/tools/dates.dart';
import 'package:budget_manager/views/category_expenses.dart';
import 'package:budget_manager/views/month_picker_sheet.dart';
import 'package:budget_manager/views/statistics.dart';
import 'package:budget_manager/views/widgets/cash_flow_chart.dart';
import 'package:budget_manager/views/widgets/custom_data_table.dart';
import 'package:budget_manager/views/widgets/info_card.dart';
import 'package:budget_manager/views/widgets/month_burndown_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../helpers/fake_server.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('loads the current month and shows its figures', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    final title = DateFormat.MMMM('en')
        .format(Dates.parseApi(server.currentMonth['start_date'] as String));
    expect(find.text(title), findsOneWidget);
    expect(find.text('BALANCE'), findsOneWidget);
    // 5000 income - 120 expense
    expect(find.textContaining('4,880.00'), findsOneWidget);
  });

  testWidgets(
      'in landscape the chart fills its column and the sums keep to the right edge',
      (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    // The 800x600 surface is landscape: chart on the left, cards on the right.
    final chart = find.byType(MonthBurndownChart);
    expect(chart, findsOneWidget);
    expect(tester.getSize(chart).height, greaterThan(350));
    expect(find.ancestor(of: chart, matching: find.byType(ListView)),
        findsNothing);

    // The card's amount ends where the card's padding begins (16 inside the
    // Card's own 4 dp margin), however wide the card.
    final expensesCard = find.widgetWithText(InfoCard, 'EXPENSES');
    final amount =
        find.descendant(of: expensesCard, matching: find.byType(FittedBox));
    expect(tester.getTopRight(amount).dx,
        closeTo(tester.getTopRight(expensesCard).dx - 20, 1));
  });

  testWidgets('the table collapses the header and the list brings it back',
      (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);
    double headerHeight() =>
        (tester.renderObject(find.byType(SliverAppBar)) as RenderSliver)
            .geometry!
            .paintExtent;
    final rail = find.byType(NavigationRail);

    await tester
        .tap(find.descendant(of: rail, matching: find.text('Expenses')));
    await tester.pumpAndSettle();
    expect(headerHeight(), greaterThan(140));
    // A wide window keeps the List / Table switch in the bar.
    expect(
        find.descendant(
            of: find.byType(SliverAppBar), matching: find.text('Table')),
        findsOneWidget);

    await tester.tap(find.text('Table'));
    await tester.pumpAndSettle();
    expect(headerHeight(), lessThan(70));

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    expect(headerHeight(), greaterThan(140));

    // A header the user had already collapsed stays collapsed.
    await tester.drag(find.text('Weekly shop'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(headerHeight(), lessThan(70));
    await tester.tap(find.text('Table'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    expect(headerHeight(), lessThan(70));
  });

  testWidgets(
      'on a phone the switch sits below the bar and stays visible when the table collapses it',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);
    double headerHeight() =>
        (tester.renderObject(find.byType(SliverAppBar)) as RenderSliver)
            .geometry!
            .paintExtent;

    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Expenses')));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(SliverAppBar), matching: find.text('Table')),
        findsNothing);
    expect(find.text('Table'), findsOneWidget);

    await tester.tap(find.text('Table'));
    await tester.pumpAndSettle();
    expect(headerHeight(), lessThan(70));
    // The body keeps clear of the toolbar, so the switch stays in view.
    expect(tester.getTopLeft(find.text('Table')).dy, greaterThan(56));
    expect(find.text('List'), findsOneWidget);
  });

  testWidgets('the table keeps clear of the system navigation bar', (
    tester,
  ) async {
    // A phone in landscape: the rail, no navigation bar of the app's own,
    // and a 48 px system bar at the bottom.
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    // The short rail labels only the selected destination, so go by icon.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byIcon(Icons.receipt_long_outlined),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Table'));
    await tester.pumpAndSettle();

    final table = find.byWidgetPredicate((w) => w is CustomDataTable);
    expect(table, findsOneWidget);
    expect(tester.getBottomLeft(table).dy, lessThanOrEqualTo(360 - 48 - 8));
  });

  testWidgets('switches months through the picker', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);
    final previous = server.months.firstWhere((m) => m['id'] == 10);
    final previousTitle = DateFormat.MMMM('en')
        .format(Dates.parseApi(previous['start_date'] as String));

    await tester.tap(find.byTooltip('Select month'));
    await tester.pumpAndSettle();
    expect(find.text('Select month'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(MonthPickerSheet), matching: find.byType(ListTile)),
        findsNWidgets(2));

    await tester.tap(find.descendant(
        of: find.byType(MonthPickerSheet), matching: find.text(previousTitle)));
    await tester.pumpAndSettle();

    expect(server.requests.last.url.queryParameters['month_id'], '10');
    expect(find.text(previousTitle), findsOneWidget);
    expect(find.byType(MonthPickerSheet), findsNothing);
  });

  testWidgets('swipes to the previous month on the Summary', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);
    final previous = server.months.firstWhere((m) => m['id'] == 10);
    final previousTitle = DateFormat.MMMM('en')
        .format(Dates.parseApi(previous['start_date'] as String));

    await tester.fling(find.text('BALANCE'), const Offset(400, 0), 1200);
    await tester.pumpAndSettle();

    expect(server.requests.last.url.queryParameters['month_id'], '10');
    expect(find.text(previousTitle), findsOneWidget);

    // Back to the newer month with a fling to the left.
    await tester.fling(find.text('BALANCE'), const Offset(-400, 0), 1200);
    await tester.pumpAndSettle();
    expect(server.requests.last.url.queryParameters['month_id'], '11');
  });

  testWidgets(
      'the title and the content slide in from the side the month lies on',
      (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);
    String titleOf(int id) => DateFormat.MMMM('en').format(Dates.parseApi(
        server.months.firstWhere((m) => m['id'] == id)['start_date']
            as String));
    final currentTitle = titleOf(11);
    final previousTitle = titleOf(10);

    await tester.fling(find.text('BALANCE'), const Offset(400, 0), 1200);
    // Let the load land, then stop part-way through the transition.
    for (var i = 0; i < 5 && find.text(previousTitle).evaluate().isEmpty; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 100));

    // Both months are on screen for the moment: the earlier one comes in
    // from the left while the later one leaves to the right, title and body.
    expect(find.text(previousTitle), findsOneWidget);
    expect(find.text(currentTitle), findsOneWidget);
    expect(tester.getTopLeft(find.text(previousTitle)).dx,
        lessThan(tester.getTopLeft(find.text(currentTitle)).dx));
    expect(find.text('BALANCE'), findsNWidgets(2));

    await tester.pumpAndSettle();
    expect(find.text(currentTitle), findsNothing);
    expect(find.text('BALANCE'), findsOneWidget);
  });

  testWidgets(
    'a slow drag pulls the month along, shows the chevron and moves past the threshold',
    (tester) async {
      final server = FakeServer();
      await pumpApp(tester, server, loggedIn: true);
      final previous = server.months.firstWhere((m) => m['id'] == 10);
      final previousTitle = DateFormat.MMMM(
        'en',
      ).format(Dates.parseApi(previous['start_date'] as String));
      final balance = find.text('BALANCE');
      final restingLeft = tester.getTopLeft(balance).dx;
      final loadsBefore = server.monthLoads;

      // Slowly, well under the flick speed: 2 px a frame. The recognizer
      // swallows the first 18 px (touch slop) before the drag counts.
      final gesture = await tester.startGesture(tester.getCenter(balance));
      Future<void> dragBy(int px) async {
        for (var i = 0; i < px ~/ 2; i++) {
          await gesture.moveBy(const Offset(2, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
      }

      await dragBy(50);
      // The content follows a little and the chevron peeks in at the left.
      expect(tester.getTopLeft(balance).dx, greaterThan(restingLeft + 5));
      expect(tester.getTopLeft(balance).dx, lessThan(restingLeft + 40));
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(server.monthLoads, loadsBefore);

      // Past the threshold a release moves, and everything settles back.
      await dragBy(70);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(server.requests.last.url.queryParameters['month_id'], '10');
      expect(find.text(previousTitle), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
      expect(tester.getTopLeft(find.text('BALANCE')).dx,
          closeTo(restingLeft, 0.01));
    },
  );

  testWidgets('a short drag eases back without changing the month', (
    tester,
  ) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);
    final balance = find.text('BALANCE');
    final restingLeft = tester.getTopLeft(balance).dx;
    final loadsBefore = server.monthLoads;

    final gesture = await tester.startGesture(tester.getCenter(balance));
    for (var i = 0; i < 25; i++) {
      await gesture.moveBy(const Offset(2, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.getTopLeft(balance).dx, greaterThan(restingLeft + 5));
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(server.monthLoads, loadsBefore);
    expect(tester.getTopLeft(balance).dx, closeTo(restingLeft, 0.01));
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
  });

  testWidgets('nothing moves when there is no month in that direction', (
    tester,
  ) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);
    final balance = find.text('BALANCE');
    final restingLeft = tester.getTopLeft(balance).dx;
    final loadsBefore = server.monthLoads;

    // The newest month is on screen: a swipe to the left has nowhere to go.
    final gesture = await tester.startGesture(tester.getCenter(balance));
    for (var i = 0; i < 15; i++) {
      await gesture.moveBy(const Offset(-2, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.getTopLeft(balance).dx, closeTo(restingLeft, 0.01));
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(server.monthLoads, loadsBefore);
  });

  testWidgets('Statistics switches between the burndown and the cash flow',
      (tester) async {
    final server = FakeServer();
    // A recurring expense, so the cash flow has something to leave out.
    server.expenses[11]!.add({
      'id': 2,
      'value': 500.0,
      'date': server.currentMonth['start_date'],
      'comment': 'Bus pass',
      'category': 2,
      'is_monthly': true,
    });
    final services = await pumpApp(tester, server, loggedIn: true);

    // The card absorbs the chart's pointer events and takes the tap itself.
    await tester.tap(find.byType(MonthBurndownChart), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(StatisticsScreen), findsOneWidget);
    expect(find.byType(BurndownLegend), findsOneWidget);
    expect(find.byType(CashFlowChart), findsNothing);

    await tester.tap(find.text('Cash flow'));
    await tester.pumpAndSettle();
    expect(find.byType(BurndownLegend), findsNothing);
    var chart = tester.widget<CashFlowChart>(find.byType(CashFlowChart));
    expect(chart.diagram.sources.map((n) => n.value).toList(), [5000]);
    expect(chart.diagram.sinks.map((n) => n.value).toList(), [500, 120, 4380]);
    expect(chart.diagram.sinks.first.category?.name, 'Transport');
    expect(chart.diagram.sinks.last.kind, CashFlowNodeKind.leftover);

    // Leaving the recurring expenses out takes them off the salary.
    await tester.tap(find.text('Include recurring expenses'));
    await tester.pumpAndSettle();
    chart = tester.widget<CashFlowChart>(find.byType(CashFlowChart));
    expect(chart.diagram.sources.map((n) => n.value).toList(), [4500]);
    expect(chart.diagram.sinks.map((n) => n.value).toList(), [120, 4380]);
    // The choice is kept on the device.
    expect(await services.session.flowIncludesRecurring(), isFalse);
  });

  testWidgets(
      'a pinch stretches the expenses column, one finger scrolls it, the rest stays',
      (tester) async {
    final server = FakeServer();
    // A tiny category: its label needs a tall column, so the stretch has far
    // to go before every label fits.
    server.expenses[11]!.add({
      'id': 2,
      'value': 15.0,
      'date': server.currentMonth['start_date'],
      'comment': 'Ticket',
      'category': 2,
      'is_monthly': false,
    });
    await pumpApp(tester, server, loggedIn: true);
    await tester.tap(find.byType(MonthBurndownChart), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash flow'));
    await tester.pumpAndSettle();
    final chart = find.byType(CashFlowChart);
    final viewport = tester.getSize(chart).height;
    ScrollPosition column() => tester
        .widget<SingleChildScrollView>(find.descendant(
            of: chart, matching: find.byType(SingleChildScrollView)))
        .controller!
        .position;
    final limit = CashFlowChart.heightToLabelAll(
      tester.element(chart),
      tester.widget<CashFlowChart>(chart).diagram,
    );
    expect(limit, greaterThan(viewport * 3));
    expect(column().maxScrollExtent, 0);

    // Two fingers 80 px apart move to 240 px apart: three times the height.
    Future<void> pinch() async {
      final centre = tester.getCenter(chart);
      final upper = await tester.startGesture(centre - const Offset(0, 40));
      final lower = await tester.startGesture(centre + const Offset(0, 40));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await upper.moveBy(const Offset(0, -8));
        await lower.moveBy(const Offset(0, 8));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await upper.up();
      await lower.up();
      await tester.pumpAndSettle();
    }

    await pinch();
    expect(column().maxScrollExtent, closeTo(viewport * 2, viewport * 0.1));
    // The chart itself keeps its size: incomes and the budget stay put.
    expect(tester.getSize(chart).height, viewport);

    // Pinching on, the stretch stops where the smallest category fits its
    // label, however far the fingers go.
    for (var i = 0;
        i < 4 && column().maxScrollExtent < limit - viewport - 1;
        i++) {
      await pinch();
    }
    expect(column().maxScrollExtent, closeTo(limit - viewport, 1));

    // One finger scrolls the column.
    await tester.drag(chart, const Offset(0, -150), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(column().pixels, greaterThan(100));
  });

  testWidgets(
      'a tap on a category in the cash flow opens its expenses, back returns',
      (tester) async {
    final server = FakeServer();
    server.expenses[11]!.add({
      'id': 2,
      'value': 500.0,
      'date': server.currentMonth['start_date'],
      'comment': 'Bus pass',
      'category': 2,
      'is_monthly': true,
    });
    await pumpApp(tester, server, loggedIn: true);
    // The card absorbs the chart's pointer events and takes the tap itself.
    await tester.tap(find.byType(MonthBurndownChart), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash flow'));
    await tester.pumpAndSettle();

    // The biggest category sits at the top of the right column.
    final rect = tester.getRect(find.byType(CashFlowChart));
    await tester.tapAt(Offset(rect.right - 4, rect.top + 12));
    await tester.pumpAndSettle();

    // The category's expenses open above the statistics.
    expect(find.byType(CategoryExpensesScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Transport'), findsOneWidget);
    expect(find.text('Bus pass'), findsOneWidget);
    expect(find.text('Weekly shop'), findsNothing);
    expect(find.byType(InputChip), findsNothing);

    // Back returns to the diagram.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(CategoryExpensesScreen), findsNothing);
    expect(find.byType(CashFlowChart), findsOneWidget);
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

  testWidgets('tapping the selected destination again reloads the month',
      (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);
    final loadsBefore = server.monthLoads;

    // The test surface is 800 px wide, so navigation is the rail.
    final incomesDestination = find.descendant(
        of: find.byType(NavigationRail), matching: find.text('Incomes'));

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

  testWidgets(
      'a phone in landscape gets a compact bar, rail actions and a menu that fits',
      (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    // One-line bar with the date range beside the name, no large title.
    expect(
        tester.widget<SliverAppBar>(find.byType(SliverAppBar)).expandedHeight,
        isNull);
    final range = server.currentMonth['start_date'] as String;
    expect(find.textContaining(Dates.parseApi(range).day.toString()),
        findsWidgets);

    // Month picker and Settings live in the rail, not in the bar.
    final rail = find.byType(NavigationRail);
    expect(find.descendant(of: rail, matching: find.byTooltip('Select month')),
        findsOneWidget);
    expect(find.descendant(of: rail, matching: find.byTooltip('Settings')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(SliverAppBar),
            matching: find.byTooltip('Settings')),
        findsNothing);
    // 360 dp leaves room for the selected destination's label only, and none
    // under the two actions.
    expect(tester.widget<NavigationRail>(rail).labelType,
        NavigationRailLabelType.selected);
    expect(find.descendant(of: rail, matching: find.text('Settings')),
        findsNothing);

    // The summary's action sheet shows every action without overflowing.
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Add expense'), findsOneWidget);
    expect(find.text('Create new'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tall window labels every rail item, the actions included',
      (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    final rail = find.byType(NavigationRail);
    expect(tester.widget<NavigationRail>(rail).labelType,
        NavigationRailLabelType.all);
    expect(find.descendant(of: rail, matching: find.text('Month')),
        findsOneWidget);
    expect(find.descendant(of: rail, matching: find.text('Settings')),
        findsOneWidget);

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

  testWidgets('Budget settings counts the categories and opens their list',
      (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Budget settings'));
    await tester.pumpAndSettle();

    final categoriesTile = find.widgetWithText(ListTile, 'Categories');
    expect(find.descendant(of: categoriesTile, matching: find.text('2')),
        findsOneWidget);

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

  testWidgets('keeps the data and shows a banner when a refresh fails',
      (tester) async {
    final server = FakeServer();
    final services = await pumpApp(tester, server, loggedIn: true);

    server.defaultMonthId =
        99; // the server now answers 500 for the default month
    services.months.data; // data stays
    await services.months.load();
    await tester.pumpAndSettle();

    expect(find.text('BALANCE'), findsOneWidget);
    expect(find.textContaining("Couldn't load data."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
