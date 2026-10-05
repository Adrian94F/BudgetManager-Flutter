import 'package:budget_manager/models/models.dart';
import 'package:budget_manager/views/widgets/history_chart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MonthHistory', () {
    final json = {
      'labels': ['1.01-31.01.2026', '1.02-28.02.2026'],
      'incomeSums': [5000.0, 5200],
      'expenseSums': [3100.5, '4000.25'],
      'balances': [1899.5, 1199.75],
    };
    final january = Month(
      id: 1,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 31),
    );
    final february = Month(
      id: 2,
      startDate: DateTime(2026, 2, 1),
      endDate: DateTime(2026, 2, 28),
    );

    test('parses the parallel lists and matches the months by start date', () {
      // The app keeps its months newest first; the server's rows are oldest
      // first.
      final history = MonthHistory.fromJson(json, months: [february, january]);

      expect(history.points.length, 2);
      expect(history.points.first.month, january);
      expect(history.points.last.month, february);
      expect(history.points.map((p) => p.incomes).toList(), [5000, 5200]);
      expect(history.points.map((p) => p.expenses).toList(), [3100.5, 4000.25]);
      expect(history.points.last.balance, 1199.75);
      expect(history.isEmpty, isFalse);
    });

    test('keeps the labels alone when the months do not line up', () {
      final history = MonthHistory.fromJson(json, months: [january]);

      expect(history.points.map((p) => p.month).toList(), [null, null]);
      expect(history.points.first.label, '1.01-31.01.2026');
    });

    test('an empty response is empty', () {
      expect(MonthHistory.fromJson(const {}).isEmpty, isTrue);
    });
  });

  group('HistoryChart.rangeFor', () {
    test('rounds out to a round step and takes zero in', () {
      final range = HistoryChart.rangeFor(const [
        HistoryPoint(label: 'a', incomes: 5243, expenses: 3100, balance: 2143),
        HistoryPoint(label: 'b', incomes: 4800, expenses: 5200, balance: -400),
      ]);

      // 5643 of spread over five steps asks for 1129, so the step is 2000.
      expect(range.step, 2000);
      expect(range.lower, -2000);
      expect(range.upper, 6000);
      expect(range.ticks, [-2000, 0, 2000, 4000, 6000]);
    });

    test('a month with nothing in it still gets a range', () {
      final range = HistoryChart.rangeFor(const [
        HistoryPoint(label: 'a', incomes: 0, expenses: 0, balance: 0),
      ]);

      expect(range.lower, 0);
      expect(range.upper, 1000);
      expect(range.ticks.first, 0);
      expect(range.ticks.last, 1000);
    });

    test('small amounts get a small step', () {
      final range = HistoryChart.rangeFor(const [
        HistoryPoint(label: 'a', incomes: 120, expenses: 80, balance: 40),
      ]);

      expect(range.step, 50);
      expect(range.lower, 0);
      expect(range.upper, 150);
    });
  });
}
