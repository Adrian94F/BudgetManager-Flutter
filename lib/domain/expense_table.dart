import '../models/models.dart';
import '../tools/dates.dart';

/// Category × day sums for the expenses table. Every expense counts toward
/// its category total even when dated outside the month; such expenses are
/// counted in [outOfRangeCount] so the screen can warn about them.
class ExpenseTable {
  final List<DateTime> days;
  final List<Category> categories;
  final Map<int, Map<DateTime, double>> _byCategoryAndDay;
  final Map<int, double> _categoryTotals;
  final Map<DateTime, double> _dailyByDay;
  final Map<DateTime, double> _totalByDay;
  final double grandDaily;
  final double grandTotal;
  final int outOfRangeCount;

  const ExpenseTable._({
    required this.days,
    required this.categories,
    required Map<int, Map<DateTime, double>> byCategoryAndDay,
    required Map<int, double> categoryTotals,
    required Map<DateTime, double> dailyByDay,
    required Map<DateTime, double> totalByDay,
    required this.grandDaily,
    required this.grandTotal,
    required this.outOfRangeCount,
  })  : _byCategoryAndDay = byCategoryAndDay,
        _categoryTotals = categoryTotals,
        _dailyByDay = dailyByDay,
        _totalByDay = totalByDay;

  factory ExpenseTable.build(
      Month month, List<Category> categories, List<Expense> expenses) {
    final sorted = [...categories]
      ..sort((a, b) => a.position.compareTo(b.position));
    final byCategoryAndDay = <int, Map<DateTime, double>>{};
    final categoryTotals = <int, double>{};
    final dailyByDay = <DateTime, double>{};
    final totalByDay = <DateTime, double>{};
    var grandDaily = 0.0;
    var grandTotal = 0.0;
    var outOfRange = 0;

    for (final expense in expenses) {
      final day = expense.date;
      (byCategoryAndDay[expense.categoryId] ??= {})
          .update(day, (v) => v + expense.value, ifAbsent: () => expense.value);
      categoryTotals.update(expense.categoryId, (v) => v + expense.value,
          ifAbsent: () => expense.value);
      totalByDay.update(day, (v) => v + expense.value,
          ifAbsent: () => expense.value);
      grandTotal += expense.value;
      if (expense.isDaily) {
        dailyByDay.update(day, (v) => v + expense.value,
            ifAbsent: () => expense.value);
        grandDaily += expense.value;
      }
      if (!month.contains(day)) outOfRange++;
    }

    return ExpenseTable._(
      days: Dates.range(month.startDate, month.endDate),
      categories: sorted,
      byCategoryAndDay: byCategoryAndDay,
      categoryTotals: categoryTotals,
      dailyByDay: dailyByDay,
      totalByDay: totalByDay,
      grandDaily: grandDaily,
      grandTotal: grandTotal,
      outOfRangeCount: outOfRange,
    );
  }

  bool get isEmpty => grandTotal == 0 && _categoryTotals.isEmpty;

  double cell(int categoryId, DateTime day) =>
      _byCategoryAndDay[categoryId]?[Dates.dateOnly(day)] ?? 0;

  double categoryTotal(int categoryId) => _categoryTotals[categoryId] ?? 0;

  /// Daily (non-recurring) expenses of [day].
  double dailyTotal(DateTime day) => _dailyByDay[Dates.dateOnly(day)] ?? 0;

  /// All expenses of [day], recurring ones included.
  double total(DateTime day) => _totalByDay[Dates.dateOnly(day)] ?? 0;
}
