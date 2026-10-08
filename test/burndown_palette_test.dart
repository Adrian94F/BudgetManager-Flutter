import 'package:budget_manager/app/theme.dart';
import 'package:budget_manager/domain/domain.dart';
import 'package:budget_manager/models/models.dart';
import 'package:budget_manager/views/widgets/month_burndown_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// January 2026 with [income] of salary and 800 spent on the 1st.
MonthData january({double income = 2000, double plannedSavings = 0}) {
  final month = Month(
      id: 1, startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 1, 31));
  return MonthData(
    months: [month],
    categories: [Category(id: 1, name: 'Food', position: 0)],
    month: month,
    incomes: [
      Income(id: 1, value: income, date: DateTime(2026, 1, 1), isSalary: true),
    ],
    expenses: [
      Expense(
          id: 1,
          value: 800,
          date: DateTime(2026, 1, 1),
          categoryId: 1,
          isMonthly: false),
    ],
    plannedSavings: plannedSavings,
  );
}

void main() {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
  const light = BurndownPalette.light;
  const dark = BurndownPalette.dark;
  final current = DateTime(2026, 1, 15);
  final later = DateTime(2026, 3, 1);

  Color colour(MonthData data, DateTime today,
          [BurndownPalette palette = light]) =>
      burndownBalanceColor(
          BurndownSeries.compute(data, today: today), scheme, palette);

  test('the palette has the shared hex values', () {
    expect(light.overBudget, const Color(0xFFE11D48));
    expect(dark.overBudget, const Color(0xFFFB7185));
    expect(light.belowTarget, const Color(0xFFD97706));
    expect(dark.belowTarget, const Color(0xFFFBBF24));
    expect(light.saved, const Color(0xFF059669));
    expect(dark.saved, const Color(0xFF34D399));
    expect(BurndownPalette.reference, const Color(0xFF9CA3AF));
  });

  test('below zero is red in the current and in a closed month', () {
    expect(colour(january(income: 500), current), light.overBudget);
    expect(colour(january(income: 500), later), light.overBudget);
    expect(colour(january(income: 500), later, dark), dark.overBudget);
  });

  test('the current month under its savings target is amber', () {
    expect(colour(january(plannedSavings: 1500), current), light.belowTarget);
    expect(
        colour(january(plannedSavings: 1500), current, dark), dark.belowTarget);
  });

  test('the current month on track has the app accent', () {
    expect(colour(january(plannedSavings: 500), current), scheme.primary);
  });

  test('a closed month that kept money is green, whatever the target', () {
    expect(colour(january(plannedSavings: 1500), later), light.saved);
    expect(colour(january(), later, dark), dark.saved);
  });
}
