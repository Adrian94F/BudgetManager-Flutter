import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../tools/formatters.dart';

/// Line colour of the balance, the same rule (and, but for the current
/// month on track, the same colours) as in the iOS app and on the web:
/// below zero is red in any month; the current month is amber while under
/// its savings target and the app's primary colour otherwise; a closed or
/// future month that kept money is green. See [BurndownPalette].
Color burndownBalanceColor(
    BurndownSeries series, ColorScheme scheme, BurndownPalette palette) {
  final latest = series.latestBalance;
  if (latest < 0) return palette.overBudget;
  if (series.isActual) {
    if (latest < series.plannedSavingsTarget) return palette.belowTarget;
    return scheme.primary;
  }
  return palette.saved;
}

/// The month's burndown, painted directly: the remaining balance per day
/// with a gradient area, the dashed ideal line down to the planned savings
/// target, weekends and today shaded. The full view adds the daily and
/// recurring expenses as bars, date labels every week, the target label and
/// a tooltip that follows a touch.
class MonthBurndownChart extends StatefulWidget {
  const MonthBurndownChart(
      {super.key, required this.series, this.isSimplified = false});

  final BurndownSeries series;
  final bool isSimplified;

  @override
  State<MonthBurndownChart> createState() => _MonthBurndownChartState();
}

class _MonthBurndownChartState extends State<MonthBurndownChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant MonthBurndownChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series != widget.series) _selectedIndex = null;
  }

  void _selectAt(Offset position, Size size) {
    final geometry =
        _ChartGeometry(size, widget.series.points.length, simplified: false);
    final index = geometry.indexAt(position.dx);
    if (index != _selectedIndex) setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    if (series.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final currency = CurrencyScope.of(context);
    final dayFormat = DateFormat('d.MM');
    final tooltipDateFormat = DateFormat.MMMEd(locale);

    final painter = _BurndownPainter(
      series: series,
      simplified: widget.isSimplified,
      selectedIndex: widget.isSimplified ? null : _selectedIndex,
      palette: _Palette(
        balance:
            burndownBalanceColor(series, scheme, BurndownPalette.of(context)),
        ideal: BurndownPalette.reference,
        target: BurndownPalette.reference,
        daily: scheme.primary.withValues(alpha: 0.45),
        monthly: scheme.tertiary.withValues(alpha: 0.45),
        grid: scheme.outlineVariant,
        weekend: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        today: scheme.primaryContainer,
        label: scheme.onSurfaceVariant,
        tooltipBackground: scheme.inverseSurface,
        tooltipText: scheme.onInverseSurface,
      ),
      labelStyle: theme.textTheme.labelSmall!,
      money: (value) => Formatters.money(value, locale, currency: currency),
      dayLabel: dayFormat.format,
      tooltipDate: tooltipDateFormat.format,
      words: (
        start: l10n.chartStart,
        balance: l10n.balance,
        daily: l10n.dailyExpenses,
        recurring: l10n.recurrentExpenses,
        plan: l10n.plannedLine,
      ),
    );

    final chart = CustomPaint(painter: painter, size: Size.infinite);
    if (widget.isSimplified) return chart;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _selectAt(details.localPosition, size),
          onHorizontalDragStart: (details) =>
              _selectAt(details.localPosition, size),
          onHorizontalDragUpdate: (details) =>
              _selectAt(details.localPosition, size),
          child: chart,
        );
      },
    );
  }
}

class _Palette {
  const _Palette({
    required this.balance,
    required this.ideal,
    required this.target,
    required this.daily,
    required this.monthly,
    required this.grid,
    required this.weekend,
    required this.today,
    required this.label,
    required this.tooltipBackground,
    required this.tooltipText,
  });

  final Color balance;
  final Color ideal;
  final Color target;
  final Color daily;
  final Color monthly;
  final Color grid;
  final Color weekend;
  final Color today;
  final Color label;
  final Color tooltipBackground;
  final Color tooltipText;

  @override
  bool operator ==(Object other) =>
      other is _Palette &&
      other.balance == balance &&
      other.ideal == ideal &&
      other.target == target &&
      other.daily == daily &&
      other.monthly == monthly &&
      other.grid == grid &&
      other.weekend == weekend &&
      other.today == today &&
      other.label == label &&
      other.tooltipBackground == tooltipBackground &&
      other.tooltipText == tooltipText;

  @override
  int get hashCode => Object.hash(balance, ideal, target, daily, monthly, grid,
      weekend, today, label, tooltipBackground, tooltipText);
}

/// Where the plot sits inside the canvas and how point indices map to x.
class _ChartGeometry {
  _ChartGeometry(Size size, this.pointCount, {required bool simplified})
      : plot = Rect.fromLTRB(
          simplified ? 36 : 44,
          8,
          size.width - 8,
          size.height - (simplified ? 6 : 22),
        );

  final Rect plot;
  final int pointCount;

  double x(int index) => pointCount <= 1
      ? plot.left
      : plot.left + plot.width * index / (pointCount - 1);

  int indexAt(double dx) {
    if (pointCount <= 1) return 0;
    final fraction = ((dx - plot.left) / plot.width).clamp(0.0, 1.0);
    return (fraction * (pointCount - 1)).round();
  }
}

/// Y range in whole thousands. The simplified view bottoms out at the
/// savings target when the balance stays above it, so the card shows the
/// part of the range that matters.
({double lower, double upper, List<double> ticks}) _yRange(
    BurndownSeries series,
    {required bool simplified}) {
  final values = [
    ...series.balances,
    ...series.ideals,
    if (!simplified) ...series.dailyExpenses,
    if (!simplified) ...series.monthlyExpenses,
  ];
  final minValue = values.reduce(math.min);
  final maxValue = values.reduce(math.max);
  final target = series.plannedSavingsTarget;
  var lower = (minValue / 1000).floor() * 1000.0;
  if (simplified && series.minBalance >= target && target > 0) {
    lower = (target / 1000).floor() * 1000.0;
  }
  final upper = math.max((maxValue / 1000).ceil() * 1000.0, lower + 1000);
  final List<double> ticks;
  if (simplified) {
    ticks = [upper, lower, if (lower < 0 && upper > 0) 0.0];
  } else {
    final step = math.max(500.0, ((upper - lower) / 5 / 500).ceil() * 500.0);
    ticks = [for (var v = lower; v <= upper + 0.5; v += step) v];
  }
  return (lower: lower, upper: upper, ticks: ticks);
}

String _compact(double value) {
  if (value == 0) return '0';
  final thousands = value / 1000;
  return thousands % 1 == 0
      ? '${thousands.toInt()}k'
      : '${thousands.toStringAsFixed(1)}k';
}

Path _dashed(Path source, double dash, double gap) {
  final result = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = math.min(distance + dash, metric.length);
      result.addPath(metric.extractPath(distance, end), Offset.zero);
      distance = end + gap;
    }
  }
  return result;
}

class _BurndownPainter extends CustomPainter {
  _BurndownPainter({
    required this.series,
    required this.simplified,
    required this.selectedIndex,
    required this.palette,
    required this.labelStyle,
    required this.money,
    required this.dayLabel,
    required this.tooltipDate,
    required this.words,
  });

  final BurndownSeries series;
  final bool simplified;
  final int? selectedIndex;
  final _Palette palette;
  final TextStyle labelStyle;
  final String Function(double) money;
  final String Function(DateTime) dayLabel;
  final String Function(DateTime) tooltipDate;
  final ({
    String start,
    String balance,
    String daily,
    String recurring,
    String plan
  }) words;

  @override
  void paint(Canvas canvas, Size size) {
    final points = series.points;
    final geometry =
        _ChartGeometry(size, points.length, simplified: simplified);
    final plot = geometry.plot;
    final range = _yRange(series, simplified: simplified);
    double y(double value) =>
        plot.bottom -
        (value - range.lower) / (range.upper - range.lower) * plot.height;

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, size.height));

    _paintBands(canvas, geometry, points);
    _paintGrid(canvas, geometry, range, y);
    if (!simplified) _paintBars(canvas, geometry, points, y);
    _paintArea(canvas, geometry, points, y);
    _paintIdeal(canvas, geometry, points, y);
    _paintBalance(canvas, geometry, points, y);
    if (!simplified && series.isActual && series.plannedSavingsTarget > 0) {
      _paintTarget(canvas, plot, y);
    }
    if (!simplified) _paintDayLabels(canvas, geometry, points);
    if (!simplified && selectedIndex != null) {
      _paintTooltip(canvas, size, geometry, points, y, selectedIndex!);
    }

    canvas.restore();
  }

  void _paintBands(
      Canvas canvas, _ChartGeometry geometry, List<BurndownPoint> points) {
    final plot = geometry.plot;
    final weekend = Paint()..color = palette.weekend;
    final today = Paint()..color = palette.today;
    for (var i = 1; i < points.length; i++) {
      final band = Rect.fromLTRB(
          geometry.x(i - 1), plot.top, geometry.x(i), plot.bottom);
      if (points[i].isWeekend) canvas.drawRect(band, weekend);
      if (series.todayIndex == i) canvas.drawRect(band, today);
    }
  }

  void _paintGrid(
      Canvas canvas,
      _ChartGeometry geometry,
      ({double lower, double upper, List<double> ticks}) range,
      double Function(double) y) {
    final plot = geometry.plot;
    final grid = Paint()
      ..color = palette.grid
      ..strokeWidth = 1;
    for (final tick in range.ticks) {
      final ty = y(tick);
      canvas.drawLine(Offset(plot.left, ty), Offset(plot.right, ty), grid);
      if (simplified && tick == 0) continue;
      final label = _text(_compact(tick), palette.label);
      label.paint(
          canvas, Offset(plot.left - 6 - label.width, ty - label.height / 2));
    }
  }

  void _paintBars(Canvas canvas, _ChartGeometry geometry,
      List<BurndownPoint> points, double Function(double) y) {
    final daily = Paint()..color = palette.daily;
    final monthly = Paint()..color = palette.monthly;
    final base = y(0);
    for (var i = 1; i < points.length; i++) {
      final point = points[i];
      final left = geometry.x(i - 1);
      final right = geometry.x(i);
      final inset = (right - left) * 0.2;
      RRect rect(double top, double bottom) => RRect.fromRectAndRadius(
          Rect.fromLTRB(left + inset, top, right - inset, bottom),
          const Radius.circular(2));
      if (point.monthlyExpenses > 0) {
        canvas.drawRRect(rect(y(point.monthlyExpenses), base), monthly);
      }
      if (point.dailyExpenses > 0) {
        canvas.drawRRect(
            rect(y(point.monthlyExpenses + point.dailyExpenses),
                y(point.monthlyExpenses)),
            daily);
      }
    }
  }

  Path _linePath(_ChartGeometry geometry, List<BurndownPoint> points,
      double Function(BurndownPoint) value, double Function(double) y) {
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final offset = Offset(geometry.x(i), y(value(points[i])));
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    return path;
  }

  void _paintArea(Canvas canvas, _ChartGeometry geometry,
      List<BurndownPoint> points, double Function(double) y) {
    final plot = geometry.plot;
    final area = _linePath(geometry, points, (p) => p.balance, y)
      ..lineTo(geometry.x(points.length - 1), plot.bottom)
      ..lineTo(geometry.x(0), plot.bottom)
      ..close();
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, plot.top),
        Offset(0, plot.bottom),
        [
          palette.balance.withValues(alpha: 0.22),
          palette.balance.withValues(alpha: 0.0)
        ],
      );
    canvas.drawPath(area, paint);
  }

  void _paintIdeal(Canvas canvas, _ChartGeometry geometry,
      List<BurndownPoint> points, double Function(double) y) {
    final path = _linePath(geometry, points, (p) => p.ideal, y);
    canvas.drawPath(
      _dashed(path, 4, 3),
      Paint()
        ..color = palette.ideal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _paintBalance(Canvas canvas, _ChartGeometry geometry,
      List<BurndownPoint> points, double Function(double) y) {
    final path = _linePath(geometry, points, (p) => p.balance, y);
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.balance
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintTarget(Canvas canvas, Rect plot, double Function(double) y) {
    final ty = y(series.plannedSavingsTarget);
    final line = Path()
      ..moveTo(plot.left, ty)
      ..lineTo(plot.right, ty);
    canvas.drawPath(
      _dashed(line, 2, 4),
      Paint()
        ..color = palette.target
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final label = _text(
        '${words.plan} ${money(series.plannedSavingsTarget)}', palette.target);
    label.paint(
        canvas, Offset(plot.right - label.width, ty - label.height - 2));
  }

  void _paintDayLabels(
      Canvas canvas, _ChartGeometry geometry, List<BurndownPoint> points) {
    final plot = geometry.plot;
    for (var i = 1; i < points.length; i += 7) {
      final day = points[i].day;
      if (day == null) continue;
      final label = _text(dayLabel(day), palette.label);
      final x = geometry.x(i - 1);
      if (x + label.width > plot.right) break;
      canvas.drawLine(Offset(x, plot.bottom), Offset(x, plot.bottom + 3),
          Paint()..color = palette.grid);
      label.paint(canvas, Offset(x, plot.bottom + 5));
    }
  }

  void _paintTooltip(Canvas canvas, Size size, _ChartGeometry geometry,
      List<BurndownPoint> points, double Function(double) y, int index) {
    final point = points[index];
    final plot = geometry.plot;
    final x = geometry.x(index);
    canvas.drawLine(
      Offset(x, plot.top),
      Offset(x, plot.bottom),
      Paint()
        ..color = palette.label
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
        Offset(x, y(point.balance)), 4, Paint()..color = palette.balance);

    final lines = [
      point.isStart ? words.start : tooltipDate(point.day!),
      '${words.balance}: ${money(point.balance)}',
      if (point.dailyExpenses > 0)
        '${words.daily}: ${money(point.dailyExpenses)}',
      if (point.monthlyExpenses > 0)
        '${words.recurring}: ${money(point.monthlyExpenses)}',
    ];
    final text = _text(lines.join('\n'), palette.tooltipText, bold: false);
    const padding = 8.0;
    final boxWidth = text.width + padding * 2;
    final boxHeight = text.height + padding * 2;
    var left = x - boxWidth / 2;
    left = left.clamp(0.0, math.max(0.0, size.width - boxWidth));
    final top = math.max(0.0, y(point.balance) - boxHeight - 12);
    final box = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, boxWidth, boxHeight),
        const Radius.circular(8));
    canvas.drawRRect(box, Paint()..color = palette.tooltipBackground);
    text.paint(canvas, Offset(left + padding, top + padding));
  }

  TextPainter _text(String text, Color color, {bool bold = false}) {
    return TextPainter(
      text: TextSpan(
          text: text,
          style: labelStyle.copyWith(
              color: color, fontWeight: bold ? FontWeight.w600 : null)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
  }

  @override
  bool shouldRepaint(covariant _BurndownPainter oldDelegate) =>
      oldDelegate.series != series ||
      oldDelegate.simplified != simplified ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.palette != palette ||
      oldDelegate.labelStyle != labelStyle;
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
    final balanceColor =
        burndownBalanceColor(series, scheme, BurndownPalette.of(context));
    Widget item(Color color, String text, {bool dashed = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: dashed ? 2 : 10,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2)),
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
        item(BurndownPalette.reference, labels.plan, dashed: true),
        item(scheme.primary.withValues(alpha: 0.45), labels.daily),
        item(scheme.tertiary.withValues(alpha: 0.45), labels.recurring),
      ],
    );
  }
}
