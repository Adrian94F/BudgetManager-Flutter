import 'package:budget_manager/l10n/app_localizations.dart';
import 'package:budget_manager/models/models.dart';
import 'package:budget_manager/tools/dates.dart';
import 'package:budget_manager/views/expenses_list.dart';
import 'package:budget_manager/views/expenses_table.dart';
import 'package:budget_manager/views/widgets/custom_data_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Amounts are above 31 so they never read as a day number of the header.
void main() {
  final today = Dates.today();
  const categories = [
    Category(id: 1, name: 'Groceries', position: 1),
    Category(id: 2, name: 'Transport', position: 2),
  ];

  /// A month with today late in it, so the table has to scroll to show it.
  final lateMonth = Month(
      id: 1,
      startDate: Dates.addDays(today, -25),
      endDate: Dates.addDays(today, 5));

  Expense expense(int id, double value, DateTime date, int category,
          {bool monthly = false}) =>
      Expense(
          id: id,
          value: value,
          date: date,
          categoryId: category,
          isMonthly: monthly);

  final mixed = [
    expense(1, 45, today, 1),
    expense(2, 300, today, 2, monthly: true),
    expense(3, 77, lateMonth.startDate, 2),
  ];

  Future<List<ExpensesFilter>> pumpTable(
      WidgetTester tester, Month month, List<Expense> expenses) async {
    final opened = <ExpensesFilter>[];
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ExpensesTableView(
          data: MonthData(
              months: [month],
              categories: categories,
              month: month,
              expenses: expenses),
          onOpenFiltered: opened.add,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return opened;
  }

  double scrollOffset(WidgetTester tester) => tester
      .state<CustomDataTableState<CellData>>(
          find.byType(CustomDataTable<CellData>))
      .subTableXController
      .offset;

  testWidgets('labels the corners in words and has no sums toggle',
      (tester) async {
    await pumpTable(tester, lateMonth, mixed);

    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Sum (daily)'), findsOneWidget);
    // The trailing column's header and the totals footer.
    expect(find.text('Sum'), findsNWidgets(2));
    expect(find.text('Σ'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('the totals footer shows only where it differs from the daily',
      (tester) async {
    await pumpTable(tester, lateMonth, mixed);

    // Today: 45 daily, 345 with the recurring 300.
    expect(find.text('345'), findsOneWidget);
    // The first day has no recurring expense: its cell and the daily footer,
    // the totals footer stays blank.
    expect(find.text('77'), findsNWidgets(2));
    // Grand daily 122, grand total 422.
    expect(find.text('122'), findsOneWidget);
    expect(find.text('422'), findsOneWidget);
    // Transport's sum.
    expect(find.text('377'), findsOneWidget);
  });

  testWidgets('without recurring expenses the totals footer is blank',
      (tester) async {
    await pumpTable(tester, lateMonth, [expense(1, 45, today, 1)]);

    // The cell, the category sum, the daily footer and the grand daily;
    // neither the totals footer nor the grand total repeat it.
    expect(find.text('45'), findsNWidgets(4));
  });

  testWidgets('opens scrolled to today, and at the start for another month',
      (tester) async {
    await pumpTable(tester, lateMonth, mixed);
    expect(scrollOffset(tester), greaterThan(0));
    // Today's column is in view.
    expect(tester.getCenter(find.text('345')).dx, lessThan(800 - 60));
    expect(tester.getCenter(find.text('345')).dx, greaterThan(130));

    final past = Month(
        id: 2,
        startDate: Dates.addDays(today, -60),
        endDate: Dates.addDays(today, -40));
    await pumpTable(tester, past, [expense(1, 45, past.startDate, 1)]);
    expect(scrollOffset(tester), 0);
  });

  testWidgets('taps open the cell, the day and the category', (tester) async {
    final opened = await pumpTable(tester, lateMonth, mixed);

    await tester.tap(find.text('300'));
    await tester.tap(find.text('345'));
    await tester.tap(find.text('${today.day}'));
    await tester.tap(find.text('Transport'));
    await tester.tap(find.text('377'));
    // The corners open nothing.
    await tester.tap(find.text('Category'));
    await tester.tap(find.text('422'));

    expect([
      for (final f in opened) (f.category, f.date)
    ], [
      (2, today),
      (null, today),
      (null, today),
      (2, null),
      (2, null),
    ]);
  });
}
