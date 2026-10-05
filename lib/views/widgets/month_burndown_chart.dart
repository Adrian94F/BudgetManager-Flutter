import 'dart:math';

import 'package:community_charts_flutter/community_charts_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthBurndownChart extends StatelessWidget {
  final List<dynamic> incomes;
  final List<dynamic> expenses;
  final DateTime startDate;
  final DateTime endDate;
  final bool isSimplified;
  final bool animate = true;

  const MonthBurndownChart({
    super.key,
    required this.incomes,
    required this.expenses,
    required this.startDate,
    required this.endDate,
    this.isSimplified = false
  });

  @override
  Widget build(BuildContext context) {
    final chartData = _prepareChartData();
    final seriesList = _createSeries(context, chartData);
    final widgetWidth = MediaQuery.of(context).orientation == Orientation.portrait
        ? MediaQuery.of(context).size.width
        : MediaQuery.of(context).size.width * 3 / 5;
    final segmentWidth = widgetWidth / (chartData.dateLabels.length);

    final allValues = [
      ...chartData.burndownValues,
      ...chartData.idealBurndownValues,
      ...chartData.dailyExpensesValues,
      ...chartData.monthlyExpensesValues,
    ];
    final minVal = allValues.reduce(min);
    final maxVal = allValues.reduce(max);
    final double axisMin = (minVal / 1000).floor() * 1000;
    final double axisMax = (maxVal / 1000).ceil() * 1000;
    final tickValues = <TickSpec<num>>[
      TickSpec(axisMax),
    ];
    if (axisMin < 0) {
      tickValues.add(TickSpec(axisMin));
    }
    if (axisMin < 0 && axisMax > 0 || axisMin == 0) {
      tickValues.add(const TickSpec(0));
    }

    return OrdinalComboChart(
      seriesList,
      primaryMeasureAxis: NumericAxisSpec(
        tickProviderSpec: isSimplified
            ? StaticNumericTickProviderSpec(tickValues)
            : null,
        tickFormatterSpec: BasicNumericTickFormatterSpec(
          (num? number) {
            if (number == null || number == 0) {
              return isSimplified ? "" : "0";
            } else {
              return "${(number / 1000.0).toStringAsFixed(0)}k";
            }
          }
        ),
        renderSpec: GridlineRendererSpec(
          labelStyle: TextStyleSpec(
            color: Theme.of(context).brightness == Brightness.light
                ? MaterialPalette.gray.shade900
                : MaterialPalette.gray.shade300,
          ),
          lineStyle: LineStyleSpec(
            color: Theme.of(context).brightness == Brightness.light
                ? MaterialPalette.gray.shade200
                : MaterialPalette.gray.shade900,
          ),
        ),
      ),
      domainAxis: const OrdinalAxisSpec(
        showAxisLine: false,
        renderSpec: NoneRenderSpec(),
      ),
      animate: animate,
      defaultRenderer: LineRendererConfig(),
      customSeriesRenderers: [
        BarRendererConfig(
          stackedBarPaddingPx: 0,
          customRendererId: 'customStackedBar',
          groupingType: BarGroupingType.stacked,
        ),
      ],
      behaviors: [
        RangeAnnotation(_getSegments(context, chartData, segmentWidth)),
      ],
    );
  }

  _ChartData _prepareChartData() {
    final normalizedStart = _normalizeDate(startDate);
    final normalizedEnd = _normalizeDate(endDate);

    final dates = <DateTime>[];
    DateTime current = normalizedStart;

    while (current.isBefore(normalizedEnd) || current.isAtSameMomentAs(normalizedEnd)) {
      dates.add(current);
      current = _addDay(current);
    }

    final dailyExpensesMap = <String, double>{};
    final monthlyExpensesMap = <String, double>{};
    double totalMonthlyExpenses = 0.0;
    double totalIncome = 0.0;

    for (var expense in expenses) {
      final value = (expense['value'] as num).toDouble();
      final dateStr = expense['date'] as String;
      final expenseDate = _normalizeDate(DateTime.parse(dateStr));
      final dateKey = _dateToKey(expenseDate);

      if (expense['is_monthly'] == true) {
        monthlyExpensesMap[dateKey] = (monthlyExpensesMap[dateKey] ?? 0.0) + value;
        totalMonthlyExpenses += value;
      } else {
        dailyExpensesMap[dateKey] = (dailyExpensesMap[dateKey] ?? 0.0) + value;
      }
    }

    for (var income in incomes) {
      totalIncome += (income['value'] as num).toDouble();
    }

    final availableBudget = totalIncome - totalMonthlyExpenses;
    final idealDailyBurn = availableBudget / dates.length;

    final dateLabels = <String>[];
    final burndownValues = <double>[];
    final idealBurndownValues = <double>[];
    final dailyExpensesValues = <double>[];
    final monthlyExpensesValues = <double>[];

    dateLabels.add("start");
    burndownValues.add(availableBudget);
    idealBurndownValues.add(availableBudget);
    dailyExpensesValues.add(0.0);
    monthlyExpensesValues.add(0.0);

    final formatter = DateFormat('d.MM');
    double currentBudget = availableBudget;
    double currentIdeal = availableBudget;

    for (int i = 0; i < dates.length; i++) {
      final date = dates[i];
      final dateKey = _dateToKey(date);
      final label = formatter.format(date);

      final dailyExpense = dailyExpensesMap[dateKey] ?? 0.0;
      final monthlyExpense = isSimplified
          ? 0.0
          : monthlyExpensesMap[dateKey] ?? 0.0;

      currentBudget -= dailyExpense;
      currentIdeal -= idealDailyBurn;
      if (currentIdeal < 0) currentIdeal = 0;

      dateLabels.add(label);
      burndownValues.add(currentBudget);
      idealBurndownValues.add(currentIdeal);
      dailyExpensesValues.add(dailyExpense);
      monthlyExpensesValues.add(monthlyExpense);
    }

    return _ChartData(
      dateLabels: dateLabels,
      dates: [normalizedStart, ...dates],
      burndownValues: burndownValues,
      idealBurndownValues: idealBurndownValues,
      dailyExpensesValues: dailyExpensesValues,
      monthlyExpensesValues: monthlyExpensesValues,
    );
  }

  List<Series<_DataPoint, String>> _createSeries(
    BuildContext context,
    _ChartData chartData,
  ) {
    final lightMode = Theme.of(context).brightness == Brightness.light;

    return [
      Series<_DataPoint, String>(
        id: 'Monthly',
        colorFn: (_, __) => lightMode
            ? MaterialPalette.indigo.makeShades(5)[4]
            : MaterialPalette.indigo.makeShades(5)[4].darker.darker.darker.darker,
        domainFn: (_DataPoint point, _) => point.label,
        measureFn: (_DataPoint point, _) => point.value,
        data: List.generate(
          chartData.dateLabels.length,
          (i) => _DataPoint(chartData.dateLabels[i], chartData.monthlyExpensesValues[i]),
        ),
      )..setAttribute(rendererIdKey, 'customStackedBar'),
      Series<_DataPoint, String>(
        id: 'Daily',
        colorFn: (_, __) => lightMode
            ? MaterialPalette.indigo.makeShades(5)[3]
            : MaterialPalette.indigo.makeShades(5)[3].darker.darker,
        domainFn: (_DataPoint point, _) => point.label,
        measureFn: (_DataPoint point, _) => point.value,
        data: List.generate(
          chartData.dateLabels.length,
          (i) => _DataPoint(chartData.dateLabels[i], chartData.dailyExpensesValues[i]),
        ),
      )..setAttribute(rendererIdKey, 'customStackedBar'),
      Series<_DataPoint, String>(
        id: 'Ideal burndown',
        colorFn: (_, __) => MaterialPalette.indigo.makeShades(5)[2],
        strokeWidthPxFn: (_, __) => 0.5,
        dashPatternFn: (_, __) => [2, 2],
        domainFn: (_DataPoint point, _) => point.label,
        measureFn: (_DataPoint point, _) => point.value,
        data: List.generate(
          chartData.dateLabels.length,
          (i) => _DataPoint(chartData.dateLabels[i], chartData.idealBurndownValues[i]),
        ),
      ),
      Series<_DataPoint, String>(
        id: 'Burndown',
        colorFn: (_, __) => MaterialPalette.indigo.shadeDefault,
        domainFn: (_DataPoint point, _) => point.label,
        measureFn: (_DataPoint point, _) => point.value,
        data: List.generate(
          chartData.dateLabels.length,
          (i) => _DataPoint(chartData.dateLabels[i], chartData.burndownValues[i]),
        ),
      ),
    ];
  }

  List<LineAnnotationSegment<Object>> _getSegments(
    BuildContext context,
    _ChartData chartData,
    double segmentWidth,
  ) {
    final segments = <LineAnnotationSegment<Object>>[];
    final lightMode = Theme.of(context).brightness == Brightness.light;
    final today = _normalizeDate(DateTime.now());

    for (int i = 1; i < chartData.dates.length; i++) {
      final date = chartData.dates[i];
      final label = chartData.dateLabels[i];

      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
        segments.add(LineAnnotationSegment(
          label,
          RangeAnnotationAxisType.domain,
          strokeWidthPx: segmentWidth,
          color: lightMode
              ? MaterialPalette.gray.shade100
              : MaterialPalette.gray.shade900.darker,
        ));
      }

      if (date.year == today.year &&
          date.month == today.month &&
          date.day == today.day) {
        segments.add(LineAnnotationSegment(
          label,
          RangeAnnotationAxisType.domain,
          strokeWidthPx: segmentWidth,
          color: lightMode
              ? MaterialPalette.indigo.makeShades(10)[9]
              : MaterialPalette.indigo.shadeDefault.darker.darker.darker.darker.darker,
        ));
      }
    }

    return segments;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  DateTime _addDay(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day + 1);
  }

  String _dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _ChartData {
  final List<String> dateLabels;
  final List<DateTime> dates;
  final List<double> burndownValues;
  final List<double> idealBurndownValues;
  final List<double> dailyExpensesValues;
  final List<double> monthlyExpensesValues;

  _ChartData({
    required this.dateLabels,
    required this.dates,
    required this.burndownValues,
    required this.idealBurndownValues,
    required this.dailyExpensesValues,
    required this.monthlyExpensesValues,
  });
}

class _DataPoint {
  final String label;
  final double value;

  _DataPoint(this.label, this.value);
}
