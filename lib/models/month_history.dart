import 'money.dart';
import 'month.dart';

/// One month of the history: the sums the server reports for it.
class HistoryPoint {
  const HistoryPoint({
    required this.label,
    this.month,
    required this.incomes,
    required this.expenses,
    required this.balance,
  });

  /// The server's label for the month, e.g. "1.01-31.01.2026".
  final String label;

  /// The month itself when it could be matched to one the app knows; it
  /// gives the dates for the axis.
  final Month? month;
  final double incomes;
  final double expenses;

  /// Incomes minus expenses.
  final double balance;
}

/// The `GET api/statistics/` response: every month's incomes, expenses and
/// balance, oldest first.
class MonthHistory {
  const MonthHistory(this.points);

  final List<HistoryPoint> points;

  static const empty = MonthHistory([]);

  bool get isEmpty => points.isEmpty;

  /// The server sends the sums in four parallel lists. [months], the app's
  /// own (in any order), are matched to them by start date when there are
  /// as many of them; otherwise the points keep only their labels.
  factory MonthHistory.fromJson(
    Map<String, dynamic> json, {
    List<Month> months = const [],
  }) {
    final labels =
        (json['labels'] as List<dynamic>? ?? const []).cast<String>();
    final incomes = json['incomeSums'] as List<dynamic>? ?? const [];
    final expenses = json['expenseSums'] as List<dynamic>? ?? const [];
    final balances = json['balances'] as List<dynamic>? ?? const [];
    final sorted = months.length == labels.length
        ? ([...months]..sort((a, b) => a.startDate.compareTo(b.startDate)))
        : null;
    Object? at(List<dynamic> values, int i) =>
        i < values.length ? values[i] : null;
    return MonthHistory([
      for (var i = 0; i < labels.length; i++)
        HistoryPoint(
          label: labels[i],
          month: sorted?[i],
          incomes: parseMoney(at(incomes, i)),
          expenses: parseMoney(at(expenses, i)),
          balance: parseMoney(at(balances, i)),
        ),
    ]);
  }
}
