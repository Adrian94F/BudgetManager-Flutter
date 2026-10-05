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

  testWidgets('navigates to the previous month with the arrow', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();

    expect(server.requests.last.url.queryParameters['month_id'], '10');
    final previous = server.months.firstWhere((m) => m['id'] == 10);
    final title = DateFormat.MMMM('en').format(Dates.parseApi(previous['start_date'] as String));
    expect(find.text(title), findsOneWidget);
    // The oldest month has no previous one.
    final previousButton = find.ancestor(of: find.byTooltip('Previous month'), matching: find.byType(IconButton)).first;
    expect(tester.widget<IconButton>(previousButton).onPressed, isNull);
  });

  testWidgets('opens the month picker from the title', (tester) async {
    final server = FakeServer();
    await pumpApp(tester, server, loggedIn: true);

    await tester.tap(find.byTooltip('Select month'));
    await tester.pumpAndSettle();

    expect(find.text('Select month'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.descendant(of: find.byType(MonthPickerSheet), matching: find.byType(ListTile)), findsNWidgets(2));
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
