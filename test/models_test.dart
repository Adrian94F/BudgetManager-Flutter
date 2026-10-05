import 'package:budget_manager/models/models.dart';
import 'package:budget_manager/tools/dates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// A response shaped like `GET api/month/`: months newest first, money as
/// floats (an empty sum as int 0), one income without a date.
final Map<String, dynamic> sampleResponse = {
  'months': [
    {'id': 11, 'start_date': '2026-09-26', 'end_date': '2026-10-25'},
    {'id': 12, 'start_date': '2026-10-26', 'end_date': '2026-11-25'},
    {'id': 10, 'start_date': '2026-08-26', 'end_date': '2026-09-25'},
  ],
  'categories': [
    {'id': 2, 'name': 'Groceries', 'position': 2},
    {'id': 1, 'name': 'Transport', 'position': 1},
  ],
  'month': {'id': 11, 'start_date': '2026-09-26', 'end_date': '2026-10-25'},
  'incomes': [
    {
      'id': 100,
      'value': 6000.0,
      'date': '2026-09-26',
      'comment': 'Pay',
      'is_salary': true
    },
    {'id': 101, 'value': 0, 'date': null, 'comment': null, 'is_salary': false},
  ],
  'expenses': [
    {
      'id': 200,
      'value': 1200.5,
      'date': '2026-09-27',
      'comment': 'Rent',
      'category': 1,
      'is_monthly': true
    },
    {
      'id': 201,
      'value': '45.20',
      'date': '2026-10-05',
      'comment': '',
      'category': 2,
      'is_monthly': false
    },
  ],
  'planned_savings': 1500.0,
};

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pl');
    await initializeDateFormatting('en');
  });

  group('MonthData.fromJson', () {
    test('parses a full response and sorts months and categories', () {
      final data = MonthData.fromJson(sampleResponse);

      expect(data.hasMonth, isTrue);
      expect(data.month!.id, 11);
      expect(data.months.map((m) => m.id), [12, 11, 10]);
      expect(data.categories.map((c) => c.name), ['Transport', 'Groceries']);
      expect(data.plannedSavings, 1500.0);
      expect(data.message, isNull);
    });

    test('reads the currency and defaults to PLN', () {
      expect(MonthData.fromJson(sampleResponse).currency, 'PLN');
      expect(
          MonthData.fromJson({...sampleResponse, 'currency': 'EUR'}).currency,
          'EUR');
      expect(
          MonthData.fromJson(sampleResponse).copyWith(currency: 'CHF').currency,
          'CHF');
    });

    test('accepts money as float, int and string', () {
      final data = MonthData.fromJson(sampleResponse);

      expect(data.incomes[0].value, 6000.0);
      expect(data.incomes[1].value, 0.0);
      expect(data.expenses[1].value, 45.2);
    });

    test('falls back to the month start for an income without a date', () {
      final data = MonthData.fromJson(sampleResponse);

      expect(data.incomes[1].hasDate, isFalse);
      expect(data.incomes[1].date, DateTime(2026, 9, 26));
      expect(data.incomes[0].hasDate, isTrue);
    });

    test('parses the no-months response', () {
      final data = MonthData.fromJson({
        'message': 'Create your first month.',
        'months': [],
        'categories': [],
        'planned_savings': 0,
      });

      expect(data.hasMonth, isFalse);
      expect(data.incomes, isEmpty);
      expect(data.expenses, isEmpty);
      expect(data.message, 'Create your first month.');
    });

    test('finds the current month and category names', () {
      final data = MonthData.fromJson(sampleResponse);

      expect(data.currentMonth(DateTime(2026, 10, 5))!.id, 11);
      expect(data.currentMonth(DateTime(2027, 1, 1)), isNull);
      expect(data.categoryName(2), 'Groceries');
      expect(data.categoryName(99), '–');
    });
  });

  group('Month', () {
    final month = Month(
        id: 1,
        startDate: DateTime(2026, 9, 26),
        endDate: DateTime(2026, 10, 25));

    test('knows its length, whether it is current, and days left', () {
      expect(month.lengthInDays, 30);
      expect(month.isActual(DateTime(2026, 10, 5)), isTrue);
      expect(month.isActual(DateTime(2026, 10, 26)), isFalse);
      expect(month.daysLeft(DateTime(2026, 10, 5)), 21);
      expect(month.daysLeft(DateTime(2026, 10, 25)), 1);
      expect(month.daysLeft(DateTime(2026, 11, 1)), 0);
    });

    test('clamps dates into its range', () {
      expect(month.clamp(DateTime(2026, 9, 1)), DateTime(2026, 9, 26));
      expect(month.clamp(DateTime(2026, 12, 1)), DateTime(2026, 10, 25));
      expect(month.clamp(DateTime(2026, 10, 5, 13, 30)), DateTime(2026, 10, 5));
    });

    test('formats titles per locale', () {
      expect(month.title('en', today: DateTime(2026, 10, 5)), 'September');
      expect(month.title('en', today: DateTime(2027, 1, 1)), 'September 2026');
      expect(month.title('pl', today: DateTime(2026, 10, 5)), 'Wrzesień');
      expect(month.rangeTitle('en'), 'Sep 26 – Oct 25, 2026');
    });
  });

  group('Dates', () {
    test('counts days across a daylight-saving change', () {
      expect(
          Dates.daysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
      expect(
          Dates.daysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2);
      expect(Dates.range(DateTime(2026, 10, 24), DateTime(2026, 10, 26)).length,
          3);
    });

    test('adds months with day clamping', () {
      expect(Dates.addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(
          Dates.addMonths(DateTime(2026, 10, 25), 1), DateTime(2026, 11, 25));
      expect(Dates.addMonths(DateTime(2026, 12, 15), 1), DateTime(2027, 1, 15));
    });

    test('formats and parses API dates', () {
      expect(Dates.formatApi(DateTime(2026, 3, 7)), '2026-03-07');
      expect(Dates.parseApi('2026-03-07'), DateTime(2026, 3, 7));
      expect(Dates.tryParseApi(null), isNull);
      expect(Dates.tryParseApi(''), isNull);
    });
  });
}
