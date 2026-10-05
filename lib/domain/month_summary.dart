import '../models/models.dart';

/// The figures shown on the Summary screen, computed the way the server's
/// `summary` view and the iOS `SummaryViewModel` compute them.
///
/// Planned savings count only while the month is the current one. The daily
/// allowance counts every daily expense of the month, today's and future
/// ones included, so already planned spending lowers it.
class MonthSummary {
  final bool isActual;

  final double salaries;
  final double otherIncomes;
  final double allIncomes;

  final double monthlyExpenses;
  final double dailyExpenses;
  final double allExpenses;

  /// Incomes left for daily spending: all incomes minus recurring expenses.
  final double incomesForDailyExpenses;

  /// Planned savings in effect: the user's value for the current month, 0
  /// for any other month.
  final double plannedSavings;

  /// Incomes minus all expenses.
  final double actualBalance;

  /// [actualBalance] minus [plannedSavings]; the headline figure.
  final double balance;

  /// Days to the end of the month, today included; 0 unless the month is current.
  final int daysLeft;

  /// What may still be spent per day; null when the month is not current,
  /// has no days left, or is already over budget.
  final double? maxDaily;

  /// Daily expenses dated today; 0 unless the month is current.
  final double todaySpendings;

  /// [todaySpendings] as a percentage of [maxDaily]; null without a positive allowance.
  final double? todayPercent;

  const MonthSummary({
    required this.isActual,
    required this.salaries,
    required this.otherIncomes,
    required this.allIncomes,
    required this.monthlyExpenses,
    required this.dailyExpenses,
    required this.allExpenses,
    required this.incomesForDailyExpenses,
    required this.plannedSavings,
    required this.actualBalance,
    required this.balance,
    required this.daysLeft,
    required this.maxDaily,
    required this.todaySpendings,
    required this.todayPercent,
  });

  static const empty = MonthSummary(
    isActual: false,
    salaries: 0,
    otherIncomes: 0,
    allIncomes: 0,
    monthlyExpenses: 0,
    dailyExpenses: 0,
    allExpenses: 0,
    incomesForDailyExpenses: 0,
    plannedSavings: 0,
    actualBalance: 0,
    balance: 0,
    daysLeft: 0,
    maxDaily: null,
    todaySpendings: 0,
    todayPercent: null,
  );

  factory MonthSummary.compute(MonthData data, {DateTime? today}) {
    final month = data.month;
    if (month == null) return empty;
    final now = today ?? DateTime.now();

    double sum(Iterable<double> values) => values.fold(0.0, (a, b) => a + b);

    final salaries = sum(data.incomes.where((i) => i.isSalary).map((i) => i.value));
    final otherIncomes = sum(data.incomes.where((i) => !i.isSalary).map((i) => i.value));
    final allIncomes = salaries + otherIncomes;

    final monthlyExpenses = sum(data.expenses.where((e) => e.isMonthly).map((e) => e.value));
    final dailyExpenses = sum(data.expenses.where((e) => e.isDaily).map((e) => e.value));
    final allExpenses = monthlyExpenses + dailyExpenses;

    final isActual = month.isActual(now);
    final plannedSavings = isActual ? data.plannedSavings : 0.0;
    final actualBalance = allIncomes - allExpenses;
    final balance = actualBalance - plannedSavings;

    final daysLeft = isActual ? month.daysLeft(now) : 0;
    final dailyBudget = allIncomes - monthlyExpenses - dailyExpenses - plannedSavings;
    final maxDaily = isActual && daysLeft > 0 && dailyBudget >= 0 ? dailyBudget / daysLeft : null;

    final todaySpendings = isActual
        ? sum(data.expenses
            .where((e) => e.isDaily && e.date.year == now.year && e.date.month == now.month && e.date.day == now.day)
            .map((e) => e.value))
        : 0.0;
    final todayPercent = maxDaily != null && maxDaily > 0 ? todaySpendings / maxDaily * 100 : null;

    return MonthSummary(
      isActual: isActual,
      salaries: salaries,
      otherIncomes: otherIncomes,
      allIncomes: allIncomes,
      monthlyExpenses: monthlyExpenses,
      dailyExpenses: dailyExpenses,
      allExpenses: allExpenses,
      incomesForDailyExpenses: allIncomes - monthlyExpenses,
      plannedSavings: plannedSavings,
      actualBalance: actualBalance,
      balance: balance,
      daysLeft: daysLeft,
      maxDaily: maxDaily,
      todaySpendings: todaySpendings,
      todayPercent: todayPercent,
    );
  }
}
