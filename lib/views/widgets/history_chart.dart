import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../models/models.dart';
import '../../tools/formatters.dart';

/// Month over month: incomes and expenses as lines, the balance as bars, one
/// column per month at a fixed width ([monthWidth]), so a phone shows a few
/// months at a time and a tablet or a landscape window many more. The plot
/// scrolls sideways and opens at the newest month; the Y axis stays put on
/// the right, and its range follows the months in view, easing from one
/// range to the next. A dashed line marks a new year. A tap on a month
/// shows its figures.
class HistoryChart extends StatefulWidget {
  const HistoryChart({super.key, required this.history});

  final MonthHistory history;

  /// Width of one month's column.
  static const monthWidth = 64.0;

  /// Width of the Y axis beside the plot: room for a tick label such as
  /// "-2.5k" and a little air, no more.
  static const axisWidth = 40.0;

  /// The Y range for [points]: from the lowest value, or zero, to the
  /// highest, rounded out to a round step with about five steps in all.
  static HistoryRange rangeFor(Iterable<HistoryPoint> points) {
    var low = 0.0;
    var high = 0.0;
    for (final p in points) {
      low = [low, p.incomes, p.expenses, p.balance].reduce(math.min);
      high = [high, p.incomes, p.expenses, p.balance].reduce(math.max);
    }
    if (high == low) high = low + 1000;
    final step = _niceStep((high - low) / 5);
    final lower = (low / step).floor() * step;
    final upper = (high / step).ceil() * step;
    return HistoryRange(lower, upper > lower ? upper : lower + step, step);
  }

  /// 1, 2 or 5 times a power of ten, the smallest not below [raw].
  static double _niceStep(double raw) {
    if (raw <= 0) return 1000;
    final magnitude =
        math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final residual = raw / magnitude;
    final factor = residual <= 1
        ? 1
        : residual <= 2
            ? 2
            : residual <= 5
                ? 5
                : 10;
    return factor * magnitude;
  }

  @override
  State<HistoryChart> createState() => _HistoryChartState();
}

/// A Y range of the history chart and the step between its ticks.
class HistoryRange {
  const HistoryRange(this.lower, this.upper, this.step);

  final double lower;
  final double upper;
  final double step;

  List<double> get ticks => [
        for (var v = (lower / step).ceil() * step;
            v <= upper + step / 2;
            v += step)
          v,
      ];

  static HistoryRange lerp(HistoryRange a, HistoryRange b, double t) =>
      HistoryRange(
        ui.lerpDouble(a.lower, b.lower, t)!,
        ui.lerpDouble(a.upper, b.upper, t)!,
        b.step,
      );

  @override
  bool operator ==(Object other) =>
      other is HistoryRange &&
      other.lower == lower &&
      other.upper == upper &&
      other.step == step;

  @override
  int get hashCode => Object.hash(lower, upper, step);
}

class _RangeTween extends Tween<HistoryRange> {
  _RangeTween({super.end});

  @override
  HistoryRange lerp(double t) => HistoryRange.lerp(begin!, end!, t);
}

class _HistoryChartState extends State<HistoryChart> {
  late final ScrollController _scroll;
  int? _selected;
  HistoryRange? _range;
  double _viewportWidth = 0;

  List<HistoryPoint> get _points => widget.history.points;

  double get _contentWidth => _points.length * HistoryChart.monthWidth;

  @override
  void initState() {
    super.initState();
    // Open at the newest month: an offset past the end is pulled back to
    // the end once the content is laid out.
    _scroll = ScrollController(initialScrollOffset: _contentWidth)
      ..addListener(_onScroll);
  }

  @override
  void didUpdateWidget(HistoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.history != widget.history) {
      _selected = null;
      _range = null;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The range of the months the viewport shows, in whole or in part, when
  /// the plot is scrolled by [offset].
  HistoryRange _visibleRange(double offset) {
    final points = _points;
    if (points.isEmpty) return HistoryChart.rangeFor(const []);
    final first = (offset / HistoryChart.monthWidth).floor().clamp(
          0,
          points.length - 1,
        );
    final last = ((offset + _viewportWidth) / HistoryChart.monthWidth)
        .ceil()
        .clamp(first + 1, points.length);
    return HistoryChart.rangeFor(points.sublist(first, last));
  }

  void _onScroll() {
    final range = _visibleRange(_scroll.offset);
    if (range != _range) setState(() => _range = range);
  }

  void _select(Offset position) {
    final index = (position.dx / HistoryChart.monthWidth).floor();
    if (index < 0 || index >= _points.length) return;
    setState(() => _selected = _selected == index ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final currency = CurrencyScope.of(context);
    final monthFormat = DateFormat.MMM(locale);
    final titleFormat = DateFormat.yMMMM(locale);
    final palette = _Palette(
      incomes: BudgetColors.of(context).success,
      expenses: scheme.error,
      bar: scheme.primary.withValues(alpha: 0.45),
      barNegative: scheme.error.withValues(alpha: 0.35),
      grid: scheme.outlineVariant,
      zero: scheme.outline,
      divider: scheme.outline,
      label: scheme.onSurfaceVariant,
      tooltipBackground: scheme.inverseSurface,
      tooltipText: scheme.onInverseSurface,
    );
    final labelStyle = theme.textTheme.labelSmall!;

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportWidth = math.max(
          constraints.maxWidth - HistoryChart.axisWidth,
          0,
        );
        final offset = _scroll.hasClients
            ? _scroll.offset
            : _contentWidth - _viewportWidth;
        final range = _range ??= _visibleRange(math.max(offset, 0));
        return TweenAnimationBuilder<HistoryRange>(
          tween: _RangeTween(end: range),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          builder: (context, range, _) => Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => _select(details.localPosition),
                    child: SizedBox(
                      key: const ValueKey('history-plot'),
                      width: _contentWidth,
                      height: constraints.maxHeight,
                      child: CustomPaint(
                        painter: _PlotPainter(
                          points: _points,
                          range: range,
                          selected: _selected,
                          palette: palette,
                          labelStyle: labelStyle,
                          monthLabel: (p) => p.month == null
                              ? p.label
                              : _capitalize(
                                  monthFormat.format(p.month!.startDate)),
                          title: (p) => p.month == null
                              ? p.label
                              : _capitalize(
                                  titleFormat.format(p.month!.startDate)),
                          money: (v) =>
                              Formatters.money(v, locale, currency: currency),
                          words: (
                            incomes: l10n.incomes,
                            expenses: l10n.expenses,
                            balance: l10n.balance,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: HistoryChart.axisWidth,
                height: constraints.maxHeight,
                child: CustomPaint(
                  painter: _AxisPainter(
                    range: range,
                    palette: palette,
                    labelStyle: labelStyle,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

/// Legend for the history chart.
class HistoryLegend extends StatelessWidget {
  const HistoryLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    Widget item(Color color, String text, {bool line = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: line ? 2 : 10,
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
        item(BudgetColors.of(context).success, l10n.incomes, line: true),
        item(scheme.error, l10n.expenses, line: true),
        item(scheme.primary.withValues(alpha: 0.45), l10n.balance),
      ],
    );
  }
}

class _Palette {
  const _Palette({
    required this.incomes,
    required this.expenses,
    required this.bar,
    required this.barNegative,
    required this.grid,
    required this.zero,
    required this.divider,
    required this.label,
    required this.tooltipBackground,
    required this.tooltipText,
  });

  final Color incomes;
  final Color expenses;
  final Color bar;
  final Color barNegative;
  final Color grid;
  final Color zero;
  final Color divider;
  final Color label;
  final Color tooltipBackground;
  final Color tooltipText;

  @override
  bool operator ==(Object other) =>
      other is _Palette &&
      other.incomes == incomes &&
      other.expenses == expenses &&
      other.bar == bar &&
      other.barNegative == barNegative &&
      other.grid == grid &&
      other.zero == zero &&
      other.divider == divider &&
      other.label == label &&
      other.tooltipBackground == tooltipBackground &&
      other.tooltipText == tooltipText;

  @override
  int get hashCode => Object.hash(
        incomes,
        expenses,
        bar,
        barNegative,
        grid,
        zero,
        divider,
        label,
        tooltipBackground,
        tooltipText,
      );
}

/// Room above the plot for the year labels, and below it for the months'.
const _topPad = 20.0;
const _bottomPad = 22.0;

Rect _plotRect(Size size) =>
    Rect.fromLTRB(0, _topPad, size.width, size.height - _bottomPad);

double _yFor(double value, HistoryRange range, Rect plot) =>
    plot.bottom -
    (value - range.lower) / (range.upper - range.lower) * plot.height;

/// Thousands with a "k" ("12k", "1.5k"); smaller amounts as they are.
String _compact(double value) {
  if (value.abs() < 1000) return value.round().toString();
  final thousands = value / 1000;
  return thousands % 1 == 0
      ? '${thousands.toInt()}k'
      : '${thousands.toStringAsFixed(1)}k';
}

TextPainter _text(String text, TextStyle style, Color color,
        {double? maxWidth}) =>
    TextPainter(
      text: TextSpan(text: text, style: style.copyWith(color: color)),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth ?? double.infinity);

class _PlotPainter extends CustomPainter {
  const _PlotPainter({
    required this.points,
    required this.range,
    required this.selected,
    required this.palette,
    required this.labelStyle,
    required this.monthLabel,
    required this.title,
    required this.money,
    required this.words,
  });

  final List<HistoryPoint> points;
  final HistoryRange range;
  final int? selected;
  final _Palette palette;
  final TextStyle labelStyle;
  final String Function(HistoryPoint) monthLabel;
  final String Function(HistoryPoint) title;
  final String Function(double) money;
  final ({String incomes, String expenses, String balance}) words;

  static const _width = HistoryChart.monthWidth;

  double _x(int i) => (i + 0.5) * _width;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _plotRect(size);
    double y(double v) => _yFor(v, range, plot);

    _paintGrid(canvas, plot, y);
    _paintYears(canvas, plot);
    _paintBars(canvas, y);
    _paintLine(canvas, y, (p) => p.expenses, palette.expenses);
    _paintLine(canvas, y, (p) => p.incomes, palette.incomes);
    _paintMonthLabels(canvas, plot);
    if (selected != null) _paintTooltip(canvas, size, plot, y, selected!);
  }

  void _paintGrid(Canvas canvas, Rect plot, double Function(double) y) {
    final grid = Paint()
      ..color = palette.grid
      ..strokeWidth = 1;
    final zero = Paint()
      ..color = palette.zero
      ..strokeWidth = 1;
    for (final tick in range.ticks) {
      final ty = y(tick);
      canvas.drawLine(
        Offset(plot.left, ty),
        Offset(plot.right, ty),
        tick == 0 ? zero : grid,
      );
    }
  }

  /// A dashed line where a new year starts, with the year above it; the
  /// first month gets its year too.
  void _paintYears(Canvas canvas, Rect plot) {
    final paint = Paint()
      ..color = palette.divider
      ..strokeWidth = 1;
    for (var i = 0; i < points.length; i++) {
      final year = points[i].month?.startDate.year;
      if (year == null) continue;
      final previous = i == 0 ? null : points[i - 1].month?.startDate.year;
      if (i > 0 && previous == year) continue;
      final x = i * _width;
      if (i > 0) {
        for (var dy = plot.top; dy < plot.bottom; dy += 6) {
          canvas.drawLine(
            Offset(x, dy),
            Offset(x, math.min(dy + 3, plot.bottom)),
            paint,
          );
        }
      }
      _text('$year', labelStyle, palette.label).paint(canvas, Offset(x + 4, 2));
    }
  }

  void _paintBars(Canvas canvas, double Function(double) y) {
    final base = y(0);
    for (var i = 0; i < points.length; i++) {
      final balance = points[i].balance;
      if (balance == 0) continue;
      final x = _x(i);
      final rect = Rect.fromLTRB(
        x - _width * 0.25,
        math.min(y(balance), base),
        x + _width * 0.25,
        math.max(y(balance), base),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()..color = balance >= 0 ? palette.bar : palette.barNegative,
      );
    }
  }

  void _paintLine(
    Canvas canvas,
    double Function(double) y,
    double Function(HistoryPoint) value,
    Color color,
  ) {
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final point = Offset(_x(i), y(value(points[i])));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final dot = Paint()..color = color;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(Offset(_x(i), y(value(points[i]))), 3, dot);
    }
  }

  void _paintMonthLabels(Canvas canvas, Rect plot) {
    for (var i = 0; i < points.length; i++) {
      final label = _text(
        monthLabel(points[i]),
        labelStyle,
        palette.label,
        maxWidth: _width - 6,
      );
      label.paint(
        canvas,
        Offset(_x(i) - label.width / 2, plot.bottom + 5),
      );
    }
  }

  void _paintTooltip(
    Canvas canvas,
    Size size,
    Rect plot,
    double Function(double) y,
    int index,
  ) {
    final point = points[index];
    final x = _x(index);
    canvas.drawLine(
      Offset(x, plot.top),
      Offset(x, plot.bottom),
      Paint()
        ..color = palette.label
        ..strokeWidth = 1,
    );
    final text = TextPainter(
      text: TextSpan(
        text: [
          title(point),
          '${words.incomes}: ${money(point.incomes)}',
          '${words.expenses}: ${money(point.expenses)}',
          '${words.balance}: ${money(point.balance)}',
        ].join('\n'),
        style: labelStyle.copyWith(color: palette.tooltipText),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    const padding = 8.0;
    final boxWidth = text.width + padding * 2;
    final boxHeight = text.height + padding * 2;
    final left = (x - boxWidth / 2)
        .clamp(
          0.0,
          math.max(0.0, size.width - boxWidth),
        )
        .toDouble();
    final anchor = math.min(y(point.incomes), y(point.expenses));
    final top = (anchor - boxHeight - 12)
        .clamp(
          _topPad,
          math.max(_topPad, plot.bottom - boxHeight),
        )
        .toDouble();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, boxWidth, boxHeight),
        const Radius.circular(8),
      ),
      Paint()..color = palette.tooltipBackground,
    );
    text.paint(canvas, Offset(left + padding, top + padding));
  }

  @override
  bool shouldRepaint(_PlotPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.range != range ||
      oldDelegate.selected != selected ||
      oldDelegate.palette != palette ||
      oldDelegate.labelStyle != labelStyle;
}

/// The Y axis: a hairline on its left and the ticks' values beside it, for
/// the range the plot shows at the moment.
class _AxisPainter extends CustomPainter {
  const _AxisPainter({
    required this.range,
    required this.palette,
    required this.labelStyle,
  });

  final HistoryRange range;
  final _Palette palette;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _plotRect(size);
    canvas.drawLine(
      Offset(0, plot.top),
      Offset(0, plot.bottom),
      Paint()
        ..color = palette.grid
        ..strokeWidth = 1,
    );
    for (final tick in range.ticks) {
      final label = _text(_compact(tick), labelStyle, palette.label);
      final ty = _yFor(tick, range, plot) - label.height / 2;
      label.paint(
        canvas,
        Offset(6, ty.clamp(0.0, size.height - label.height).toDouble()),
      );
    }
  }

  @override
  bool shouldRepaint(_AxisPainter oldDelegate) =>
      oldDelegate.range != range ||
      oldDelegate.palette != palette ||
      oldDelegate.labelStyle != labelStyle;
}
