import 'dart:math';

import 'package:community_charts_flutter/community_charts_flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';

/// The month's burndown: remaining balance per day against the ideal line
/// that runs straight to the planned savings target, with weekends and today
/// shaded. The full view adds the daily and recurring expenses as bars.
///
/// Line colour follows the iOS app: error below zero, tertiary when the
/// current month is below its savings target, primary otherwise; a closed
/// month is green when money was left and red when not.
class MonthBurndownChart extends StatelessWidget {
  const MonthBurndownChart({super.key, required this.series, this.isSimplified = false});

  final BurndownSeries series;
  final bool isSimplified;

  static charts.Color _c(Color color) => charts.ColorUtil.fromDartColor(color);

  Color _balanceColor(ColorScheme scheme, BudgetColors budget) {
    final latest = series.latestBalance;
    if (series.isActual) {
      if (latest < 0) return scheme.error;
      if (latest < series.plannedSavingsTarget) return scheme.tertiary;
      return scheme.primary;
    }
    return latest < 0 ? scheme.error : budget.success;
  }

  /// Y range in whole thousands. The simplified view bottoms out at the
  /// savings target when the balance stays above it, so the card shows the
  /// part of the range that matters.
  ({double lower, double upper, List<double> ticks}) _yRange() {
    final values = [
      ...series.balances,
      ...series.ideals,
      if (!isSimplified) ...series.dailyExpenses,
      if (!isSimplified) ...series.monthlyExpenses,
    ];
    final minValue = values.reduce(min);
    final maxValue = values.reduce(max);
    final target = series.plannedSavingsTarget;
    var lower = (minValue / 1000).floor() * 1000.0;
    if (isSimplified && series.minBalance >= target && target > 0) {
      lower = (target / 1000).floor() * 1000.0;
    }
    final upper = max((maxValue / 1000).ceil() * 1000.0, lower + 1000);
    final ticks = [upper, lower, if (lower < 0 && upper > 0) 0.0];
    return (lower: lower, upper: upper, ticks: ticks);
  }

  static String _formatTick(num? value, {required bool hideZero}) {
    if (value == null || value == 0) return hideZero ? '' : '0';
    final thousands = value / 1000;
    return thousands % 1 == 0 ? '${thousands.toInt()}k' : '${thousands.toStringAsFixed(1)}k';
  }

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final budget = BudgetColors.of(context);
    final points = series.points;
    final dayFormat = DateFormat('d.MM');
    final labels = [for (final p in points) p.isStart ? 'start' : dayFormat.format(p.day!)];
    String label(BurndownPoint p) => labels[p.index];
    final range = _yRange();
    final balanceColor = _balanceColor(scheme, budget);

    final seriesList = <charts.Series<BurndownPoint, String>>[
      if (!isSimplified)
        charts.Series<BurndownPoint, String>(
          id: 'Monthly',
          colorFn: (_, __) => _c(scheme.tertiary.withValues(alpha: 0.45)),
          domainFn: (p, _) => label(p),
          measureFn: (p, _) => p.monthlyExpenses,
          data: points,
        )..setAttribute(charts.rendererIdKey, 'bars'),
      if (!isSimplified)
        charts.Series<BurndownPoint, String>(
          id: 'Daily',
          colorFn: (_, __) => _c(scheme.primary.withValues(alpha: 0.45)),
          domainFn: (p, _) => label(p),
          measureFn: (p, _) => p.dailyExpenses,
          data: points,
        )..setAttribute(charts.rendererIdKey, 'bars'),
      charts.Series<BurndownPoint, String>(
        id: 'Ideal',
        colorFn: (_, __) => _c(scheme.outline),
        strokeWidthPxFn: (_, __) => 1,
        dashPatternFn: (_, __) => const [4, 3],
        domainFn: (p, _) => label(p),
        measureFn: (p, _) => p.ideal,
        data: points,
      ),
      charts.Series<BurndownPoint, String>(
        id: 'Balance',
        colorFn: (_, __) => _c(balanceColor),
        strokeWidthPxFn: (_, __) => 2,
        domainFn: (p, _) => label(p),
        measureFn: (p, _) => p.balance,
        data: points,
      )..setAttribute(charts.rendererIdKey, 'balance'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = constraints.maxWidth / labels.length;
        final segments = <charts.LineAnnotationSegment<String>>[
          for (final p in points)
            if (p.isWeekend)
              charts.LineAnnotationSegment<String>(
                label(p),
                charts.RangeAnnotationAxisType.domain,
                strokeWidthPx: segmentWidth,
                color: _c(scheme.surfaceContainerHighest.withValues(alpha: 0.7)),
              ),
          if (series.todayIndex != null)
            charts.LineAnnotationSegment<String>(
              labels[series.todayIndex!],
              charts.RangeAnnotationAxisType.domain,
              strokeWidthPx: segmentWidth,
              color: _c(scheme.primaryContainer),
            ),
        ];

        return charts.OrdinalComboChart(
          seriesList,
          animate: !isSimplified,
          defaultRenderer: charts.LineRendererConfig(),
          customSeriesRenderers: [
            charts.LineRendererConfig(customRendererId: 'balance', includeArea: true, areaOpacity: 0.12),
            charts.BarRendererConfig(
              customRendererId: 'bars',
              groupingType: charts.BarGroupingType.stacked,
              stackedBarPaddingPx: 0,
            ),
          ],
          primaryMeasureAxis: charts.NumericAxisSpec(
            viewport: charts.NumericExtents(range.lower, range.upper),
            tickProviderSpec: isSimplified
                ? charts.StaticNumericTickProviderSpec([for (final t in range.ticks) charts.TickSpec(t)])
                : null,
            tickFormatterSpec: charts.BasicNumericTickFormatterSpec(
              (value) => _formatTick(value, hideZero: isSimplified),
            ),
            renderSpec: charts.GridlineRendererSpec(
              labelStyle: charts.TextStyleSpec(color: _c(scheme.onSurfaceVariant), fontSize: 11),
              lineStyle: charts.LineStyleSpec(color: _c(scheme.outlineVariant)),
            ),
          ),
          domainAxis: const charts.OrdinalAxisSpec(
            showAxisLine: false,
            renderSpec: charts.NoneRenderSpec(),
          ),
          behaviors: [charts.RangeAnnotation(segments)],
        );
      },
    );
  }
}

/// Legend for the full chart.
class BurndownLegend extends StatelessWidget {
  const BurndownLegend({super.key, required this.series, required this.labels});

  final BurndownSeries series;

  /// Balance, plan, daily, recurring.
  final ({String balance, String plan, String daily, String recurring}) labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final budget = BudgetColors.of(context);
    final balanceColor = MonthBurndownChart(series: series)._balanceColor(scheme, budget);
    Widget item(Color color, String text, {bool dashed = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: dashed ? 2 : 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(text, style: Theme.of(context).textTheme.bodySmall),
          ],
        );
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        item(balanceColor, labels.balance),
        item(scheme.outline, labels.plan, dashed: true),
        item(scheme.primary.withValues(alpha: 0.45), labels.daily),
        item(scheme.tertiary.withValues(alpha: 0.45), labels.recurring),
      ],
    );
  }
}
