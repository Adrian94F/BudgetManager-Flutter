import '../models/models.dart';
import '../tools/dates.dart';

/// One point of the burndown: the opening point (index 0, [day] null), or the
/// state after a day's daily expenses.
class BurndownPoint {
  final int index;
  final DateTime? day;

  /// Remaining balance after this day's daily expenses.
  final double balance;

  /// Where the balance should be if spending were spread evenly down to the
  /// planned savings target.
  final double ideal;
  final double dailyExpenses;
  final double monthlyExpenses;

  const BurndownPoint({
    required this.index,
    required this.day,
    required this.balance,
    required this.ideal,
    required this.dailyExpenses,
    required this.monthlyExpenses,
  });

  bool get isStart => day == null;
  bool get isWeekend => day != null && Dates.isWeekend(day!);
}

/// The burndown series of a month, as the server's `MonthChartData` and the
/// iOS `BurndownChartViewModel` build it: it starts at all incomes minus all
/// recurring expenses and drops by each day's daily expenses. Daily expenses
/// dated outside the month are skipped. The ideal line runs straight from the
/// start to the planned savings target, which is 0 for a month that is not
/// current.
class BurndownSeries {
  final List<BurndownPoint> points;
  final double startingBalance;
  final double plannedSavingsTarget;
  final bool isActual;

  /// Index of today's point, when today falls inside the month.
  final int? todayIndex;

  const BurndownSeries({
    required this.points,
    required this.startingBalance,
    required this.plannedSavingsTarget,
    required this.isActual,
    required this.todayIndex,
  });

  static const empty = BurndownSeries(
    points: [],
    startingBalance: 0,
    plannedSavingsTarget: 0,
    isActual: false,
    todayIndex: null,
  );

  factory BurndownSeries.compute(MonthData data, {DateTime? today}) {
    final month = data.month;
    if (month == null) return empty;
    final now = Dates.dateOnly(today ?? DateTime.now());

    final isActual = month.isActual(now);
    final target = isActual ? data.plannedSavings : 0.0;

    var start = 0.0;
    for (final income in data.incomes) {
      start += income.value;
    }
    for (final expense in data.expenses) {
      if (expense.isMonthly) start -= expense.value;
    }

    final dailyByDay = <DateTime, double>{};
    final monthlyByDay = <DateTime, double>{};
    for (final expense in data.expenses) {
      final map = expense.isMonthly ? monthlyByDay : dailyByDay;
      map[expense.date] = (map[expense.date] ?? 0) + expense.value;
    }

    final days = Dates.range(month.startDate, month.endDate);
    final totalDays = days.length;
    final idealDailyBurn = totalDays > 0 ? (start - target) / totalDays : 0.0;

    final points = <BurndownPoint>[
      BurndownPoint(
          index: 0,
          day: null,
          balance: start,
          ideal: start,
          dailyExpenses: 0,
          monthlyExpenses: 0),
    ];
    var balance = start;
    int? todayIndex;
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final daily = dailyByDay[day] ?? 0;
      balance -= daily;
      if (day == now) todayIndex = i + 1;
      points.add(BurndownPoint(
        index: i + 1,
        day: day,
        balance: balance,
        ideal: start - idealDailyBurn * (i + 1),
        dailyExpenses: daily,
        monthlyExpenses: monthlyByDay[day] ?? 0,
      ));
    }

    return BurndownSeries(
      points: points,
      startingBalance: start,
      plannedSavingsTarget: target,
      isActual: isActual,
      todayIndex: todayIndex,
    );
  }

  bool get isEmpty => points.isEmpty;

  double get latestBalance => points.isEmpty ? 0 : points.last.balance;

  List<double> get balances => points.map((p) => p.balance).toList();
  List<double> get ideals => points.map((p) => p.ideal).toList();
  List<double> get dailyExpenses => points.map((p) => p.dailyExpenses).toList();
  List<double> get monthlyExpenses =>
      points.map((p) => p.monthlyExpenses).toList();

  double get minBalance => points.isEmpty
      ? 0
      : points.map((p) => p.balance).reduce((a, b) => a < b ? a : b);

  double get maxValue => points.isEmpty
      ? 0
      : points
          .expand((p) => [p.balance, p.ideal])
          .reduce((a, b) => a > b ? a : b);
}
