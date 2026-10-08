import 'dart:math' as math;

import '../models/models.dart';

/// One category's share of the month's spending.
class CashFlowCategory {
  const CashFlowCategory({
    required this.category,
    required this.daily,
    required this.monthly,
  });

  final Category category;

  /// One-off (daily) expenses in the category.
  final double daily;

  /// Recurring (monthly) expenses in the category.
  final double monthly;

  double get total => daily + monthly;
}

/// What a node of the cash flow diagram stands for.
enum CashFlowNodeKind { salary, otherIncome, budget, category, leftover }

/// A node of the diagram with the amount that flows through it.
class CashFlowNode {
  const CashFlowNode(this.kind, this.value, {this.category});

  final CashFlowNodeKind kind;
  final double value;

  /// Set for [CashFlowNodeKind.category].
  final Category? category;
}

/// The diagram: every source flows into the budget and the budget flows out
/// to every sink. The budget node is as big as the larger side, so a month
/// in the red (more spent than earned) shows the gap on its inflow side.
class CashFlowDiagram {
  const CashFlowDiagram({
    required this.sources,
    required this.budget,
    required this.sinks,
  });

  /// Salary and other income, in that order; only what is above zero.
  final List<CashFlowNode> sources;
  final CashFlowNode budget;

  /// Categories largest first, then the leftover when there is one.
  final List<CashFlowNode> sinks;

  bool get isEmpty => sources.isEmpty && sinks.isEmpty;
}

/// The month's money from where it came to where it went, as the web's Cash
/// flow page shows it (`views.flow` on the server): salary and other income
/// into the budget, the budget out to the categories, largest first, and to
/// whatever is left. The [diagram] can leave the recurring expenses out:
/// they then come straight off the salary, the budget is the daily budget
/// and the categories show their daily part only. The leftover is the same
/// either way. Categories can also be hidden, as with the web page's
/// "Categories" filter: their bands are simply left out, while the incomes
/// and the leftover stay as they are, so the budget node keeps its size and
/// the hidden spending shows as the part of it that flows nowhere.
class CashFlow {
  const CashFlow({
    required this.salary,
    required this.otherIncomes,
    required this.categories,
  });

  final double salary;
  final double otherIncomes;

  /// Categories with any spending, largest total first.
  final List<CashFlowCategory> categories;

  static const empty = CashFlow(salary: 0, otherIncomes: 0, categories: []);

  double get allIncomes => salary + otherIncomes;

  double get recurringExpenses =>
      categories.fold(0, (sum, c) => sum + c.monthly);

  double get allExpenses => categories.fold(0, (sum, c) => sum + c.total);

  /// Incomes minus expenses; negative when the month is in the red.
  double get leftover => allIncomes - allExpenses;

  bool get isEmpty => allIncomes == 0 && allExpenses == 0;

  static CashFlow compute(MonthData data) {
    var salary = 0.0;
    var other = 0.0;
    for (final income in data.incomes) {
      if (income.isSalary) {
        salary += income.value;
      } else {
        other += income.value;
      }
    }
    final daily = <int, double>{};
    final monthly = <int, double>{};
    for (final expense in data.expenses) {
      final sums = expense.isMonthly ? monthly : daily;
      sums[expense.categoryId] =
          (sums[expense.categoryId] ?? 0) + expense.value;
    }
    final categories = [
      for (final category in data.categories)
        if ((daily[category.id] ?? 0) + (monthly[category.id] ?? 0) > 0)
          CashFlowCategory(
            category: category,
            daily: daily[category.id] ?? 0,
            monthly: monthly[category.id] ?? 0,
          ),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return CashFlow(
        salary: salary, otherIncomes: other, categories: categories);
  }

  /// The diagram with the recurring expenses in, or with them taken off the
  /// salary and out of the categories, without the categories whose ids are
  /// in [hiddenCategoryIds]. Hiding changes neither the sources nor the
  /// leftover (the web computes both from all expenses and only drops the
  /// hidden categories' links), so nothing is redistributed.
  CashFlowDiagram diagram({
    required bool includeRecurring,
    Set<int> hiddenCategoryIds = const {},
  }) {
    final salaryValue =
        includeRecurring ? salary : math.max(salary - recurringExpenses, 0.0);
    final sources = [
      if (salaryValue > 0) CashFlowNode(CashFlowNodeKind.salary, salaryValue),
      if (otherIncomes > 0)
        CashFlowNode(CashFlowNodeKind.otherIncome, otherIncomes),
    ];
    final sinks = [
      for (final c in categories)
        if (!hiddenCategoryIds.contains(c.category.id) &&
            (includeRecurring ? c.total : c.daily) > 0)
          CashFlowNode(
            CashFlowNodeKind.category,
            includeRecurring ? c.total : c.daily,
            category: c.category,
          ),
    ]..sort((a, b) => b.value.compareTo(a.value));
    if (leftover > 0) {
      sinks.add(CashFlowNode(CashFlowNodeKind.leftover, leftover));
    }
    final inflow = sources.fold(0.0, (sum, n) => sum + n.value);
    final outflow = sinks.fold(0.0, (sum, n) => sum + n.value);
    return CashFlowDiagram(
      sources: sources,
      budget: CashFlowNode(CashFlowNodeKind.budget, math.max(inflow, outflow)),
      sinks: sinks,
    );
  }
}
