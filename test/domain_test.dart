import 'package:budget_manager/domain/domain.dart';
import 'package:budget_manager/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

// The fixtures mirror the server's tests/test_calculator.py and
// tests/test_chart_data.py so both ends agree on the numbers.

final food = Category(id: 1, name: 'Food', position: 0);
final rent = Category(id: 2, name: 'Rent', position: 1);

/// Three-day month 2026-01-01..03: 2137 salary, 666 recurring rent on day 1,
/// 69 and 67 daily food on days 1 and 2.
MonthData threeDayMonth({double plannedSavings = 0}) {
  final month = Month(
      id: 1, startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 3));
  return MonthData(
    months: [month],
    categories: [food, rent],
    month: month,
    incomes: [
      Income(id: 1, value: 2137, date: DateTime(2026, 1, 1), isSalary: true),
    ],
    expenses: [
      Expense(
          id: 1,
          value: 666,
          date: DateTime(2026, 1, 1),
          categoryId: rent.id,
          isMonthly: true),
      Expense(
          id: 2,
          value: 69,
          date: DateTime(2026, 1, 1),
          categoryId: food.id,
          isMonthly: false),
      Expense(
          id: 3,
          value: 67,
          date: DateTime(2026, 1, 2),
          categoryId: food.id,
          isMonthly: false),
    ],
    plannedSavings: plannedSavings,
  );
}

void main() {
  group('CashFlow', () {
    test(
        'splits incomes and groups spending by category like the server flow view',
        () {
      final data = threeDayMonth().copyWith(incomes: [
        Income(id: 1, value: 2137, date: DateTime(2026, 1, 1), isSalary: true),
        Income(id: 2, value: 420, date: DateTime(2026, 1, 1), isSalary: false),
      ]);
      final flow = CashFlow.compute(data);

      expect(flow.salary, 2137);
      expect(flow.otherIncomes, 420);
      expect(flow.allExpenses, 802);
      expect(flow.recurringExpenses, 666);
      expect(flow.leftover, 1755);
      expect(flow.categories.map((c) => c.category.name).toList(),
          ['Rent', 'Food']);
      expect(flow.categories.first.monthly, 666);
      expect(flow.categories.last.daily, 136);
      expect(flow.isEmpty, isFalse);
    });

    test('the diagram runs everything through the budget, leftover last', () {
      final diagram =
          CashFlow.compute(threeDayMonth()).diagram(includeRecurring: true);

      expect(diagram.sources.map((n) => n.kind).toList(),
          [CashFlowNodeKind.salary]);
      expect(diagram.sources.single.value, 2137);
      expect(diagram.budget.value, 2137);
      expect(diagram.sinks.map((n) => n.kind).toList(), [
        CashFlowNodeKind.category,
        CashFlowNodeKind.category,
        CashFlowNodeKind.leftover,
      ]);
      expect(diagram.sinks.map((n) => n.value).toList(), [666, 136, 1335]);
      expect(diagram.sinks.first.category, rent);
    });

    test(
        'without the recurring expenses they come off the salary and the daily budget balances',
        () {
      final diagram =
          CashFlow.compute(threeDayMonth()).diagram(includeRecurring: false);

      expect(diagram.sources.single.value, 2137 - 666);
      expect(diagram.sinks.map((n) => n.value).toList(), [136, 1335]);
      expect(diagram.sinks.first.category, food);
      expect(diagram.budget.value, 1471);
    });

    test(
        'a month in the red has no leftover and a budget as big as the spending',
        () {
      final data = threeDayMonth().copyWith(incomes: [
        Income(id: 1, value: 500, date: DateTime(2026, 1, 1), isSalary: true),
      ]);
      final flow = CashFlow.compute(data);
      expect(flow.leftover, 500 - 802);

      final diagram = flow.diagram(includeRecurring: true);
      expect(diagram.sinks.map((n) => n.kind),
          everyElement(CashFlowNodeKind.category));
      expect(diagram.budget.value, 802);
    });

    test('an empty month has an empty flow', () {
      final flow =
          CashFlow.compute(threeDayMonth().copyWith(incomes: [], expenses: []));
      expect(flow.isEmpty, isTrue);
      expect(flow.diagram(includeRecurring: true).isEmpty, isTrue);
    });
  });

  group('MonthSummary', () {
    test('sums incomes and expenses like the server calculator', () {
      final data = threeDayMonth().copyWith(incomes: [
        Income(id: 1, value: 2137, date: DateTime(2026, 1, 1), isSalary: true),
        Income(id: 2, value: 420, date: DateTime(2026, 1, 1), isSalary: false),
      ]);
      final s = MonthSummary.compute(data, today: DateTime(2026, 6, 1));

      expect(s.allIncomes, 2557);
      expect(s.salaries, 2137);
      expect(s.otherIncomes, 420);
      expect(s.allExpenses, 802);
      expect(s.monthlyExpenses, 666);
      expect(s.dailyExpenses, 136);
      expect(s.incomesForDailyExpenses, 2557 - 666);
    });

    test('is all zeros for an empty month and empty data', () {
      final data = threeDayMonth().copyWith(incomes: [], expenses: []);
      final s = MonthSummary.compute(data, today: DateTime(2026, 1, 2));

      expect(s.allIncomes, 0);
      expect(s.allExpenses, 0);
      expect(s.balance, 0);
      expect(MonthSummary.compute(const MonthData(months: [], categories: [])),
          MonthSummary.empty);
    });

    test('applies planned savings and the daily allowance in the current month',
        () {
      final s = MonthSummary.compute(threeDayMonth(plannedSavings: 1000),
          today: DateTime(2026, 1, 2));

      expect(s.isActual, isTrue);
      expect(s.plannedSavings, 1000);
      expect(s.actualBalance, 2137 - 802);
      expect(s.balance, 2137 - 802 - 1000);
      expect(s.daysLeft, 2);
      // (2137 - 666 - 136 - 1000) / 2 days left, future spending included
      expect(s.maxDaily, closeTo(167.5, 1e-9));
      expect(s.todaySpendings, 67);
      expect(s.todayPercent, closeTo(67 / 167.5 * 100, 1e-9));
    });

    test('ignores planned savings and the allowance outside the current month',
        () {
      final s = MonthSummary.compute(threeDayMonth(plannedSavings: 1000),
          today: DateTime(2026, 2, 10));

      expect(s.isActual, isFalse);
      expect(s.plannedSavings, 0);
      expect(s.balance, s.actualBalance);
      expect(s.daysLeft, 0);
      expect(s.maxDaily, isNull);
      expect(s.todaySpendings, 0);
      expect(s.todayPercent, isNull);
    });

    test('has no allowance when over budget', () {
      final s = MonthSummary.compute(threeDayMonth(plannedSavings: 5000),
          today: DateTime(2026, 1, 1));

      expect(s.balance, lessThan(0));
      expect(s.maxDaily, isNull);
      expect(s.todayPercent, isNull);
    });

    test('counts the last day as one day left', () {
      final s =
          MonthSummary.compute(threeDayMonth(), today: DateTime(2026, 1, 3));

      expect(s.daysLeft, 1);
      expect(s.maxDaily, closeTo(2137 - 666 - 136, 1e-9));
    });
  });

  group('BurndownSeries', () {
    test('matches the server chart data for the three-day month', () {
      final b =
          BurndownSeries.compute(threeDayMonth(), today: DateTime(2026, 6, 1));

      expect(b.points.length, 4);
      expect(b.points.first.isStart, isTrue);
      expect(b.points.skip(1).map((p) => p.day),
          [DateTime(2026, 1, 1), DateTime(2026, 1, 2), DateTime(2026, 1, 3)]);
      expect(b.dailyExpenses, [0, 69, 67, 0]);
      expect(b.monthlyExpenses, [0, 666, 0, 0]);
      expect(b.startingBalance, 1471);
      expect(b.balances, [1471, 1402, 1335, 1335]);
      expect(b.latestBalance, 1335);
    });

    test('is flat zero for an empty month', () {
      final data = threeDayMonth().copyWith(incomes: [], expenses: []);
      final b = BurndownSeries.compute(data, today: DateTime(2026, 6, 1));

      expect(b.balances, [0, 0, 0, 0]);
      expect(b.ideals, [0, 0, 0, 0]);
    });

    test('handles a single-day month', () {
      final month = Month(
          id: 2,
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 1));
      final data = MonthData(
        months: [month],
        categories: const [],
        month: month,
        incomes: [
          Income(id: 1, value: 420, date: DateTime(2026, 3, 1), isSalary: true)
        ],
      );
      final b = BurndownSeries.compute(data, today: DateTime(2026, 6, 1));

      expect(b.balances, [420, 420]);
    });

    test(
        'runs the ideal line to the planned savings target in the current month',
        () {
      final b = BurndownSeries.compute(threeDayMonth(plannedSavings: 571),
          today: DateTime(2026, 1, 2));

      expect(b.isActual, isTrue);
      expect(b.plannedSavingsTarget, 571);
      expect(b.ideals.first, 1471);
      expect(b.ideals.last, closeTo(571, 1e-9));
      expect(b.ideals[1], closeTo(1471 - 300, 1e-9));
      expect(b.todayIndex, 2);
    });

    test('runs the ideal line to zero and has no today marker for a past month',
        () {
      final b = BurndownSeries.compute(threeDayMonth(plannedSavings: 571),
          today: DateTime(2026, 2, 1));

      expect(b.plannedSavingsTarget, 0);
      expect(b.ideals.last, closeTo(0, 1e-9));
      expect(b.todayIndex, isNull);
    });

    test('skips daily expenses dated outside the month', () {
      final data = threeDayMonth();
      final withStray = data.copyWith(expenses: [
        ...data.expenses,
        Expense(
            id: 9,
            value: 500,
            date: DateTime(2026, 1, 20),
            categoryId: food.id,
            isMonthly: false),
      ]);
      final b = BurndownSeries.compute(withStray, today: DateTime(2026, 6, 1));

      expect(b.balances, [1471, 1402, 1335, 1335]);
    });
  });

  group('ExpenseTable', () {
    test('sums cells, categories, days and totals', () {
      final data = threeDayMonth();
      final t = ExpenseTable.build(data.month!, data.categories, data.expenses);

      expect(t.days.length, 3);
      expect(t.categories.map((c) => c.name), ['Food', 'Rent']);
      expect(t.cell(food.id, DateTime(2026, 1, 1)), 69);
      expect(t.cell(rent.id, DateTime(2026, 1, 1)), 666);
      expect(t.cell(food.id, DateTime(2026, 1, 3)), 0);
      expect(t.categoryTotal(food.id), 136);
      expect(t.categoryTotal(rent.id), 666);
      expect(t.dailyTotal(DateTime(2026, 1, 1)), 69);
      expect(t.total(DateTime(2026, 1, 1)), 735);
      expect(t.grandDaily, 136);
      expect(t.grandTotal, 802);
      expect(t.outOfRangeCount, 0);
      expect(t.isEmpty, isFalse);
    });

    test('counts expenses dated outside the month and keeps DST days', () {
      final month = Month(
          id: 3,
          startDate: DateTime(2026, 10, 24),
          endDate: DateTime(2026, 10, 26));
      final t = ExpenseTable.build(month, [
        food
      ], [
        Expense(
            id: 1,
            value: 10,
            date: DateTime(2026, 10, 25),
            categoryId: food.id,
            isMonthly: false),
        Expense(
            id: 2,
            value: 20,
            date: DateTime(2026, 11, 2),
            categoryId: food.id,
            isMonthly: false),
      ]);

      expect(t.days, [
        DateTime(2026, 10, 24),
        DateTime(2026, 10, 25),
        DateTime(2026, 10, 26)
      ]);
      expect(t.cell(food.id, DateTime(2026, 10, 25)), 10);
      expect(t.categoryTotal(food.id), 30);
      expect(t.outOfRangeCount, 1);
    });
  });

  group('BudgetRules', () {
    test('ranks daily categories by use, ties by id', () {
      final expenses = [
        Expense(
            id: 1,
            value: 1,
            date: DateTime(2026, 1, 1),
            categoryId: 3,
            isMonthly: false),
        Expense(
            id: 2,
            value: 1,
            date: DateTime(2026, 1, 1),
            categoryId: 3,
            isMonthly: false),
        Expense(
            id: 3,
            value: 1,
            date: DateTime(2026, 1, 1),
            categoryId: 2,
            isMonthly: false),
        Expense(
            id: 4,
            value: 1,
            date: DateTime(2026, 1, 1),
            categoryId: 1,
            isMonthly: false),
        Expense(
            id: 5,
            value: 1,
            date: DateTime(2026, 1, 1),
            categoryId: 9,
            isMonthly: true),
      ];

      expect(BudgetRules.topCategoryIds(expenses), [3, 1, 2]);
      expect(BudgetRules.topCategoryIds(expenses, limit: 1), [3]);
    });

    test('proposes the next month from the last one', () {
      final last = Month(
          id: 1,
          startDate: DateTime(2026, 9, 26),
          endDate: DateTime(2026, 10, 25));
      final next = BudgetRules.nextMonthRange(last);

      expect(next.start, DateTime(2026, 10, 26));
      expect(next.end, DateTime(2026, 11, 25));
    });

    test('proposes the current calendar month as the first month', () {
      final first = BudgetRules.firstMonthRange(today: DateTime(2026, 2, 14));

      expect(first.start, DateTime(2026, 2, 1));
      expect(first.end, DateTime(2026, 2, 28));
    });

    test('defaults a new entry to today inside the month', () {
      final month = Month(
          id: 1,
          startDate: DateTime(2026, 9, 26),
          endDate: DateTime(2026, 10, 25));

      expect(
          BudgetRules.defaultEntryDate(month, today: DateTime(2026, 10, 5, 9)),
          DateTime(2026, 10, 5));
      expect(BudgetRules.defaultEntryDate(month, today: DateTime(2026, 12, 1)),
          DateTime(2026, 10, 25));
      expect(BudgetRules.defaultEntryDate(month, today: DateTime(2026, 1, 1)),
          DateTime(2026, 9, 26));
    });
  });
}
