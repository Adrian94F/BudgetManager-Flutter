import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../models/models.dart';
import '../../tools/formatters.dart';
import 'category_style.dart';

/// The month's cash flow as a Sankey diagram: the sources on the left, the
/// budget at a third of the width, the categories and the leftover on the
/// right, each node as tall as its amount. The links are translucent bands
/// shaded from one end's colour to the other's; a category keeps the colour
/// it has everywhere else in the app (quieter, see [categoryMuting]),
/// incomes are the primary colour, the leftover the "saved" green. A node
/// tall enough gets a label with its amount beside it, in the node's colour:
/// on the roomy right side name and amount share one line, on the left the
/// amount goes under the name. A node too short for a label has none.
///
/// The expenses column can be stretched with a pinch, up to the height at
/// which every category has its label ([heightToLabelAll]), and scrolled
/// with one finger. The sources and the budget stay as they are; a band
/// reaches a category only while the category is on screen, so bands come
/// and go as the column scrolls. A tap on a category (its node, label or
/// band) calls [onCategoryTap], which is how a small one is told apart.
class CashFlowChart extends StatefulWidget {
  const CashFlowChart({
    super.key,
    required this.diagram,
    required this.includeRecurring,
    this.onCategoryTap,
  });

  final CashFlowDiagram diagram;

  /// Whether the recurring expenses are in the diagram; it decides what the
  /// salary and budget nodes are called.
  final bool includeRecurring;
  final ValueChanged<Category>? onCategoryTap;

  /// How far a label's text may stand out over each end of its node, in
  /// logical pixels: a node up to twice this shorter than its text still
  /// gets the label. Tune to taste.
  static const labelOverhang = 1.0;

  /// How much of a category's own saturation the diagram takes away, 0 to
  /// 1. The colours categories have in the table and the list are vivid
  /// for small marks; as wide bands they are quieter. Tune to taste.
  static const categoryMuting = 0.3;

  /// How many times its own height the expenses column may be stretched to
  /// at the very most, whatever [heightToLabelAll] says.
  static const maxZoom = 100.0;

  static Color _muted(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withSaturation(hsl.saturation * (1 - categoryMuting)).toColor();
  }

  /// The expenses column's height at which every category and the leftover
  /// is tall enough for its one-line label, so the stretch need go no
  /// further; zero for an empty diagram.
  static double heightToLabelAll(
    BuildContext context,
    CashFlowDiagram diagram,
  ) {
    final total = diagram.budget.value;
    if (total <= 0) return 0;
    final line = (TextPainter(
      text: TextSpan(text: '0', style: Theme.of(context).textTheme.labelMedium),
      textDirection: Directionality.of(context),
    )..layout())
        .height;
    var needed = 0.0;
    for (final node in diagram.sinks) {
      if (node.value <= 0) continue;
      needed = math.max(
        needed,
        total * (line - 2 * labelOverhang) / node.value,
      );
    }
    return needed + math.max(diagram.sinks.length - 1, 0) * _Geometry.nodeGap;
  }

  @override
  State<CashFlowChart> createState() => _CashFlowChartState();
}

class _CashFlowChartState extends State<CashFlowChart> {
  /// The expenses column's scroll position. An empty scroll view owns it,
  /// for the physics (fling, clamping, overscroll); the column itself is
  /// painted, and the painter follows the position.
  final _scroll = ScrollController();
  double _zoom = 1;
  double _viewport = 0;

  /// The one-finger scroll in progress, driven through the position. The
  /// scroll view ignores pointers itself, since its drag recognizer would
  /// fight the pinch's scale recognizer.
  Drag? _drag;
  int _pointers = 0;
  double _startZoom = 1;
  double _startOffset = 0;
  double _startFocalY = 0;

  /// The stretch the diagram allows now.
  double get _maxZoom {
    if (_viewport <= 0) return CashFlowChart.maxZoom;
    final height = CashFlowChart.heightToLabelAll(context, widget.diagram);
    return (height / _viewport).clamp(1.0, CashFlowChart.maxZoom);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _rebase(double focalY) {
    _startZoom = _zoom;
    _startOffset = _scroll.hasClients ? _scroll.offset : 0;
    _startFocalY = focalY;
  }

  void _startDrag(Offset global, Offset local) {
    if (!_scroll.hasClients) return;
    _drag = _scroll.position.drag(
      DragStartDetails(globalPosition: global, localPosition: local),
      () => _drag = null,
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _pointers = details.pointerCount;
    _rebase(details.localFocalPoint.dy);
    if (_pointers == 1) {
      _startDrag(details.focalPoint, details.localFocalPoint);
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount != _pointers) {
      // A finger came or went: the recognizer starts its scale over, and so
      // does the stretch; a scroll in progress ends.
      _pointers = details.pointerCount;
      _drag?.cancel();
      _drag = null;
      _rebase(details.localFocalPoint.dy);
      if (_pointers == 1) {
        _startDrag(details.focalPoint, details.localFocalPoint);
      }
    }
    if (_pointers >= 2) {
      final zoom = (_startZoom * details.verticalScale).clamp(1.0, _maxZoom);
      if (zoom == _zoom) return;
      // The point of the column that was under the fingers when they came
      // down stretches with it; scrolling there keeps it under them.
      final contentY = (_startOffset + _startFocalY) * zoom / _startZoom;
      final offset = contentY - details.localFocalPoint.dy;
      setState(() => _zoom = zoom);
      // The new extent exists once this frame has laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        _scroll.jumpTo(offset.clamp(0.0, _scroll.position.maxScrollExtent));
      });
    } else {
      _drag?.update(
        DragUpdateDetails(
          globalPosition: details.focalPoint,
          localPosition: details.localFocalPoint,
          delta: Offset(0, details.focalPointDelta.dy),
          primaryDelta: details.focalPointDelta.dy,
        ),
      );
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _drag?.end(
      DragEndDetails(
        velocity: details.velocity,
        primaryVelocity: details.velocity.pixelsPerSecond.dy,
      ),
    );
    _drag = null;
    _pointers = 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final budgetColors = BudgetColors.of(context);
    final diagram = widget.diagram;

    String nameOf(CashFlowNode node) => switch (node.kind) {
          CashFlowNodeKind.salary =>
            widget.includeRecurring ? l10n.salary : l10n.salaryAfterRecurring,
          CashFlowNodeKind.otherIncome => l10n.otherIncome,
          CashFlowNodeKind.budget =>
            widget.includeRecurring ? l10n.budget : l10n.dailyBudget,
          CashFlowNodeKind.category => node.category!.name,
          CashFlowNodeKind.leftover => l10n.leftover,
        };
    (Color, Color) colorsOf(CashFlowNode node) => switch (node.kind) {
          CashFlowNodeKind.salary || CashFlowNodeKind.otherIncome => (
              scheme.primary,
              scheme.primary
            ),
          CashFlowNodeKind.budget => (scheme.outline, scheme.onSurfaceVariant),
          CashFlowNodeKind.category => switch (CategoryStyle.forBrightness(
              node.category!.name,
              theme.brightness,
            )) {
              final style => (
                  CashFlowChart._muted(style.accent),
                  CashFlowChart._muted(style.onContainer),
                ),
            },
          CashFlowNodeKind.leftover => (
              budgetColors.success,
              budgetColors.success,
            ),
        };
    _NodeStyle styleOf(CashFlowNode node) {
      final (color, labelColor) = colorsOf(node);
      return _NodeStyle(
        name: nameOf(node),
        // Whole units, as on the web page: the diagram is about proportions.
        amount: Formatters.moneyOf(context, node.value, decimalDigits: 0),
        color: color,
        labelColor: labelColor,
      );
    }

    final styles = <CashFlowNode, _NodeStyle>{
      for (final node in diagram.sources) node: styleOf(node),
      diagram.budget: styleOf(diagram.budget),
      for (final node in diagram.sinks) node: styleOf(node),
    };
    final text = _TextStyles(
      name: theme.textTheme.labelMedium!,
      amountInline: theme.textTheme.labelMedium!.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      amountBelow: theme.textTheme.labelSmall!.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      direction: Directionality.of(context),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        _viewport = size.height;
        // A new limit (the diagram changed) may be below the stretch reached.
        _zoom = _zoom.clamp(1.0, _maxZoom);
        final painter = _SankeyPainter(
          diagram: diagram,
          styles: styles,
          text: text,
          zoom: _zoom,
          scroll: _scroll,
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Measure the pinch from where the fingers came down, not from
          // where the gesture was told apart from a tap, so the column
          // follows the fingers exactly.
          dragStartBehavior: DragStartBehavior.down,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          onTapUp: widget.onCategoryTap == null
              ? null
              : (details) {
                  final category = painter.categoryAt(
                    details.localPosition,
                    size,
                  );
                  if (category != null) widget.onCategoryTap!(category);
                },
          child: Stack(
            fit: StackFit.expand,
            children: [
              SingleChildScrollView(
                controller: _scroll,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(height: size.height * _zoom),
              ),
              CustomPaint(painter: painter),
            ],
          ),
        );
      },
    );
  }
}

class _NodeStyle {
  const _NodeStyle({
    required this.name,
    required this.amount,
    required this.color,
    required this.labelColor,
  });

  final String name;
  final String amount;

  /// The node and its bands.
  final Color color;

  /// The node's name in its label, so the label reads as the node's.
  final Color labelColor;
}

class _TextStyles {
  const _TextStyles({
    required this.name,
    required this.amountInline,
    required this.amountBelow,
    required this.direction,
  });

  final TextStyle name;

  /// The amount on the name's line: the name's size, muted.
  final TextStyle amountInline;

  /// The amount under the name: a size smaller.
  final TextStyle amountBelow;
  final TextDirection direction;
}

class _NodeBox {
  const _NodeBox(this.node, this.rect);

  final CashFlowNode node;
  final Rect rect;
}

/// A node's label, laid out and placed. [inline] puts the name and the
/// amount on one line, the amount at the node's edge and the name before
/// it; otherwise the amount, if there is one, goes under the name.
class _PlacedLabel {
  _PlacedLabel({
    required this.box,
    required this.name,
    required this.amount,
    required this.inline,
    required this.alignRight,
    required this.x,
    required this.top,
  });

  final _NodeBox box;
  final TextPainter name;
  final TextPainter? amount;
  final bool inline;

  /// Whether [x] is the right edge of the text (a label left of its node).
  final bool alignRight;
  final double x;
  double top;

  static const inlineGap = 6.0;

  double get height => inline
      ? math.max(name.height, amount?.height ?? 0)
      : name.height + (amount?.height ?? 0);

  double get width => inline
      ? name.width + (amount == null ? 0 : inlineGap + amount!.width)
      : math.max(name.width, amount?.width ?? 0);

  Rect get rect =>
      Rect.fromLTWH(alignRight ? x - width : x, top, width, height);

  /// Whether the label sits beside its own node, give or take
  /// [CashFlowChart.labelOverhang] over each of the node's ends.
  bool get fitsItsNode {
    const slack = CashFlowChart.labelOverhang;
    return top >= box.rect.top - slack &&
        top + height <= box.rect.bottom + slack;
  }

  /// Paints the label moved down by [dy].
  void paint(Canvas canvas, {double dy = 0}) {
    final amount = this.amount;
    final y = top + dy;
    if (inline) {
      if (alignRight) {
        var right = x;
        if (amount != null) {
          amount.paint(canvas, Offset(right - amount.width, y));
          right -= amount.width + inlineGap;
        }
        name.paint(canvas, Offset(right - name.width, y));
      } else {
        name.paint(canvas, Offset(x, y));
        amount?.paint(canvas, Offset(x + name.width + inlineGap, y));
      }
      return;
    }
    var lineY = y;
    for (final painter in [name, if (amount != null) amount]) {
      painter.paint(canvas, Offset(alignRight ? x - painter.width : x, lineY));
      lineY += painter.height;
    }
  }
}

/// Where everything sits. The sources, the budget and the bands between
/// them are laid out in the viewport; the expenses column is laid out in
/// its own, taller space (the viewport's height times the stretch) and
/// scrolls past the viewport, its bands drawn from the budget to wherever
/// its nodes stand at the moment. Heights are proportional to the amounts;
/// the viewport uses one scale, the stretched column its own.
class _Geometry {
  const _Geometry({
    required this.size,
    required this.sources,
    required this.budget,
    required this.inflows,
    required this.leftLabels,
    required this.contentHeight,
    required this.sinks,
    required this.sinkLabels,
    required this.slotTops,
    required this.slotHeights,
  });

  final Size size;
  final List<_NodeBox> sources;
  final _NodeBox budget;

  /// The bands from the sources into the budget.
  final List<Path> inflows;
  final List<_PlacedLabel> leftLabels;

  /// The expenses column's height; its nodes and labels are in its space.
  final double contentHeight;
  final List<_NodeBox> sinks;
  final List<_PlacedLabel> sinkLabels;

  /// Where on the budget's right side each sink's band starts, and how
  /// tall it is there; the slots stay put while the column scrolls.
  final List<double> slotTops;
  final List<double> slotHeights;

  static const nodeWidth = 10.0;

  /// Room between two nodes of a column, when the height allows.
  static const nodeGap = 8.0;

  /// A node is never thinner than this, so the tiniest amount still shows;
  /// the bands keep their exact proportions, so the stacks on the budget's
  /// two sides match its height.
  static const minNodeHeight = 2.0;

  /// Where the budget stands: a third of the way across, so the categories'
  /// side, which has the most labels, gets the most room.
  static const budgetFraction = 1 / 3;

  /// Room between a node and its label.
  static const labelGap = 8.0;

  /// Room between two labels on one side.
  static const labelSpacing = 2.0;

  /// A side at least this wide fits a name and its amount on one line.
  static const inlineWidth = 120.0;

  factory _Geometry.compute(
    CashFlowDiagram diagram,
    Size size,
    Map<CashFlowNode, _NodeStyle> styles,
    _TextStyles text, {
    required double zoom,
  }) {
    final total = diagram.budget.value;
    final height = size.height;
    final contentHeight = height * zoom;

    // Nodes in a column stand a gap apart, unless the column is so short
    // that the gaps would eat its height; then they shrink so that all of
    // them take at most a quarter of it.
    double gapFor(int count, double columnHeight) => math.min(
          nodeGap,
          0.25 * columnHeight / math.max(count - 1, 1),
        );
    double gapsFor(int count, double columnHeight) =>
        math.max(count - 1, 0) * gapFor(count, columnHeight);
    double scaleFor(double columnHeight, double gaps) =>
        total > 0 ? math.max(columnHeight - gaps, 0) / total : 0.0;
    double nodeHeightOf(double value, double scale) =>
        math.max(value * scale, value > 0 ? minNodeHeight : 0);

    List<_NodeBox> column(
      List<CashFlowNode> nodes,
      double x,
      double columnHeight,
      double scale,
      double gap,
    ) {
      final heights = [for (final n in nodes) nodeHeightOf(n.value, scale)];
      final used = heights.fold(0.0, (sum, h) => sum + h) +
          math.max(nodes.length - 1, 0) * gap;
      var y = (columnHeight - used) / 2;
      final boxes = <_NodeBox>[];
      for (var i = 0; i < nodes.length; i++) {
        boxes.add(
          _NodeBox(nodes[i], Rect.fromLTWH(x, y, nodeWidth, heights[i])),
        );
        y += heights[i] + gap;
      }
      return boxes;
    }

    // The viewport's scale is the one every column would share without a
    // stretch, so an unstretched diagram looks the same as ever.
    final viewportScale = scaleFor(
      height,
      math.max(
        gapsFor(diagram.sources.length, height),
        gapsFor(diagram.sinks.length, height),
      ),
    );
    final sources = column(
      diagram.sources,
      0,
      height,
      viewportScale,
      gapFor(diagram.sources.length, height),
    );
    final budget = column(
      [diagram.budget],
      size.width * budgetFraction - nodeWidth / 2,
      height,
      viewportScale,
      0,
    ).single;

    final sinkGap = gapFor(diagram.sinks.length, contentHeight);
    final sinks = column(
      diagram.sinks,
      size.width - nodeWidth,
      contentHeight,
      scaleFor(contentHeight, gapsFor(diagram.sinks.length, contentHeight)),
      sinkGap,
    );

    // Bands stack top to bottom on the budget's sides in the nodes' order,
    // at exactly their share of its height; what the inflow leaves
    // uncovered at the bottom is the month's deficit.
    final inflows = <Path>[];
    var inY = budget.rect.top;
    for (final source in sources) {
      final h = source.node.value * viewportScale;
      inflows.add(
        _band(
          source.rect.right,
          source.rect.top,
          source.rect.bottom,
          budget.rect.left,
          inY,
          inY + h,
        ),
      );
      inY += h;
    }
    final slotTops = <double>[];
    final slotHeights = <double>[];
    var outY = budget.rect.top;
    for (final sink in sinks) {
      final h = sink.node.value * viewportScale;
      slotTops.add(outY);
      slotHeights.add(h);
      outY += h;
    }

    // Labels, only where they fit beside their node. The sources' (right of
    // their nodes) and the budget's (left of its node, at the top, since
    // the node spans the height) share the narrow left side, so they are
    // settled together and keep out of each other's way. The sinks' labels
    // have the wide right side; each sits within its own node, and the
    // nodes do not overlap, so neither do the labels.
    final leftWidth = math.max(
      budget.rect.left - nodeWidth - 2 * labelGap,
      0.0,
    );
    final rightWidth = math.max(
      size.width - nodeWidth - budget.rect.right - 2 * labelGap,
      0.0,
    );
    final leftLabels = leftWidth < 24
        ? const <_PlacedLabel>[]
        : _settle(
            [
              _label(
                budget,
                styles,
                text,
                maxWidth: leftWidth,
                inline: false,
                alignRight: true,
                x: budget.rect.left - labelGap,
                top: budget.rect.top + 2,
              ),
              for (final box in sources)
                _label(
                  box,
                  styles,
                  text,
                  maxWidth: leftWidth,
                  inline: false,
                  alignRight: false,
                  x: nodeWidth + labelGap,
                ),
            ].nonNulls.toList(),
            height);
    final sinkLabels = rightWidth < 24
        ? const <_PlacedLabel>[]
        : [
            for (final box in sinks)
              _label(
                box,
                styles,
                text,
                maxWidth: rightWidth,
                inline: rightWidth >= inlineWidth,
                alignRight: true,
                x: size.width - nodeWidth - labelGap,
              ),
          ].nonNulls.toList();

    return _Geometry(
      size: size,
      sources: sources,
      budget: budget,
      inflows: inflows,
      leftLabels: leftLabels,
      contentHeight: contentHeight,
      sinks: sinks,
      sinkLabels: sinkLabels,
      slotTops: slotTops,
      slotHeights: slotHeights,
    );
  }

  /// The part of the viewport the expenses column scrolls through.
  Rect get sinkArea =>
      Rect.fromLTRB(budget.rect.right, 0, size.width, size.height);

  /// Whether the sink at [i] shows in the viewport when the column is
  /// scrolled by [offset].
  bool sinkVisible(int i, double offset) {
    final rect = sinks[i].rect.shift(Offset(0, -offset));
    return rect.bottom > 0 && rect.top < size.height;
  }

  /// The band from the budget to the sink at [i], the column scrolled by
  /// [offset].
  Path sinkBand(int i, double offset) {
    final rect = sinks[i].rect;
    return _band(
      budget.rect.right,
      slotTops[i],
      slotTops[i] + slotHeights[i],
      rect.left,
      rect.top - offset,
      rect.bottom - offset,
    );
  }

  /// A node's label laid out to fit [maxWidth] and the node's height, at
  /// [top] or else centred on the node; null when the node is too short
  /// even for the name alone. Inline, the amount is measured first and the
  /// name gets what is left; when that is next to nothing, or the line does
  /// not fit the node, the label falls back to the amount under the name,
  /// then to the name alone.
  static _PlacedLabel? _label(
    _NodeBox box,
    Map<CashFlowNode, _NodeStyle> styles,
    _TextStyles text, {
    required double maxWidth,
    required bool inline,
    required bool alignRight,
    required double x,
    double? top,
  }) {
    final style = styles[box.node]!;
    final room = box.rect.height + 2 * CashFlowChart.labelOverhang;
    _PlacedLabel place(TextPainter name, TextPainter? amount, bool inline) {
      final label = _PlacedLabel(
        box: box,
        name: name,
        amount: amount,
        inline: inline,
        alignRight: alignRight,
        x: x,
        top: 0,
      );
      label.top = top ?? box.rect.center.dy - label.height / 2;
      return label;
    }

    if (inline) {
      final amount = _layout(
        style.amount,
        text.amountInline,
        null,
        text,
        maxWidth,
      );
      final nameWidth = maxWidth - amount.width - _PlacedLabel.inlineGap;
      if (nameWidth >= 40 && amount.height <= room) {
        return place(
          _layout(style.name, text.name, style.labelColor, text, nameWidth),
          amount,
          true,
        );
      }
    }
    final name =
        _layout(style.name, text.name, style.labelColor, text, maxWidth);
    if (name.height > room) return null;
    final amount =
        _layout(style.amount, text.amountBelow, null, text, maxWidth);
    return place(
      name,
      name.height + amount.height <= room ? amount : null,
      false,
    );
  }

  /// Keeps one side's labels apart: in order from the top, a label that
  /// would overlap the one above moves down, and the whole run moves back
  /// up when the last one would run off the bottom. A label that ends up
  /// away from its node is dropped.
  static List<_PlacedLabel> _settle(List<_PlacedLabel> labels, double height) {
    labels.sort((a, b) => a.top.compareTo(b.top));
    var nextTop = 0.0;
    for (final label in labels) {
      label.top = math.max(label.top, nextTop);
      nextTop = label.top + label.height + labelSpacing;
    }
    final overflow = nextTop - labelSpacing - height;
    if (overflow > 0) {
      for (final label in labels) {
        label.top = math.max(label.top - overflow, 0);
      }
    }
    return [
      for (final label in labels)
        if (label.fitsItsNode) label,
    ];
  }

  static TextPainter _layout(
    String value,
    TextStyle style,
    Color? color,
    _TextStyles text,
    double maxWidth,
  ) =>
      TextPainter(
        text: TextSpan(
          text: value,
          style: color == null ? style : style.copyWith(color: color),
        ),
        textDirection: text.direction,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);

  /// A band from the span [y0a]..[y0b] at [x0] to [y1a]..[y1b] at [x1].
  static Path _band(
    double x0,
    double y0a,
    double y0b,
    double x1,
    double y1a,
    double y1b,
  ) {
    final cx = (x0 + x1) / 2;
    return Path()
      ..moveTo(x0, y0a)
      ..cubicTo(cx, y0a, cx, y1a, x1, y1a)
      ..lineTo(x1, y1b)
      ..cubicTo(cx, y1b, cx, y0b, x0, y0b)
      ..close();
  }

  /// The category under [point], the column scrolled by [offset]: its
  /// node, its label or its band.
  Category? categoryAt(Offset point, double offset) {
    final shifted = Offset(point.dx, point.dy + offset);
    for (final sink in sinks) {
      final category = sink.node.category;
      if (category != null && sink.rect.inflate(6).contains(shifted)) {
        return category;
      }
    }
    for (final label in sinkLabels) {
      final category = label.box.node.category;
      if (category != null && label.rect.inflate(4).contains(shifted)) {
        return category;
      }
    }
    for (var i = 0; i < sinks.length; i++) {
      final category = sinks[i].node.category;
      if (category != null &&
          sinkVisible(i, offset) &&
          sinkBand(i, offset).contains(point)) {
        return category;
      }
    }
    return null;
  }
}

class _SankeyPainter extends CustomPainter {
  _SankeyPainter({
    required this.diagram,
    required this.styles,
    required this.text,
    required this.zoom,
    required this.scroll,
  }) : super(repaint: scroll);

  final CashFlowDiagram diagram;
  final Map<CashFlowNode, _NodeStyle> styles;
  final _TextStyles text;
  final double zoom;

  /// The expenses column's scroll position; a change repaints.
  final ScrollController scroll;

  _Geometry? _geometry;

  static const bandAlpha = 0.35;
  static const nodeRadius = Radius.circular(3);

  double get _offset => scroll.hasClients ? scroll.offset : 0;

  _Geometry geometryFor(Size size) {
    if (_geometry?.size != size) {
      _geometry = _Geometry.compute(diagram, size, styles, text, zoom: zoom);
    }
    return _geometry!;
  }

  Category? categoryAt(Offset point, Size size) =>
      geometryFor(size).categoryAt(point, _offset);

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometryFor(size);
    final offset = _offset;

    for (var i = 0; i < g.sources.length; i++) {
      canvas.drawPath(
        g.inflows[i],
        _bandPaint(g.sources[i], g.budget),
      );
    }
    // The expenses column: only what is in view, bands included, clipped to
    // its area so a node half scrolled out is cut at the edge.
    canvas.save();
    canvas.clipRect(g.sinkArea);
    for (var i = 0; i < g.sinks.length; i++) {
      if (!g.sinkVisible(i, offset)) continue;
      canvas.drawPath(g.sinkBand(i, offset), _bandPaint(g.budget, g.sinks[i]));
    }
    for (var i = 0; i < g.sinks.length; i++) {
      if (!g.sinkVisible(i, offset)) continue;
      _node(canvas, g.sinks[i], dy: -offset);
    }
    for (final label in g.sinkLabels) {
      final rect = label.rect.shift(Offset(0, -offset));
      if (rect.bottom < 0 || rect.top > size.height) continue;
      label.paint(canvas, dy: -offset);
    }
    canvas.restore();

    for (final box in [...g.sources, g.budget]) {
      _node(canvas, box);
    }
    for (final label in g.leftLabels) {
      label.paint(canvas);
    }
  }

  Paint _bandPaint(_NodeBox from, _NodeBox to) {
    final fromColor = styles[from.node]!.color;
    final toColor = styles[to.node]!.color;
    return Paint()
      ..shader = ui.Gradient.linear(
        Offset(from.rect.right, 0),
        Offset(to.rect.left, 0),
        [
          fromColor.withValues(alpha: bandAlpha),
          toColor.withValues(alpha: bandAlpha),
        ],
      );
  }

  void _node(Canvas canvas, _NodeBox box, {double dy = 0}) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(box.rect.shift(Offset(0, dy)), nodeRadius),
      Paint()..color = styles[box.node]!.color,
    );
  }

  @override
  bool shouldRepaint(_SankeyPainter oldDelegate) =>
      oldDelegate.diagram != diagram ||
      oldDelegate.styles != styles ||
      oldDelegate.text != text ||
      oldDelegate.zoom != zoom ||
      oldDelegate.scroll != scroll;
}
