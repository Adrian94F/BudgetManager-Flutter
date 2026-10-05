import 'dart:math' as math;
import 'dart:ui' as ui;

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
/// it has everywhere else in the app, incomes are the primary colour, the
/// leftover the "saved" green. A node tall enough gets a label with its
/// amount beside it, in the node's colour: on the roomy right side name and
/// amount share one line, on the left the amount goes under the name. A
/// node too short for a label has none; a tap on a category (its node,
/// label or band) calls [onCategoryTap], which is how a small one is told
/// apart.
class CashFlowChart extends StatelessWidget {
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
  static const labelOverhang = 4.0;

  /// How much of a category's own saturation the diagram takes away, 0 to
  /// 1. The colours categories have in the table and the list are vivid
  /// for small marks; as wide bands they are quieter. Tune to taste.
  static const categoryMuting = 0.5;

  static Color _muted(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withSaturation(hsl.saturation * (1 - categoryMuting)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final budgetColors = BudgetColors.of(context);

    String nameOf(CashFlowNode node) => switch (node.kind) {
          CashFlowNodeKind.salary =>
            includeRecurring ? l10n.salary : l10n.salaryAfterRecurring,
          CashFlowNodeKind.otherIncome => l10n.otherIncome,
          CashFlowNodeKind.budget =>
            includeRecurring ? l10n.budget : l10n.dailyBudget,
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
              final style => (_muted(style.accent), _muted(style.onContainer)),
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
        final geometry = _Geometry.compute(diagram, size, styles, text);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: onCategoryTap == null
              ? null
              : (details) {
                  final category = geometry.categoryAt(details.localPosition);
                  if (category != null) onCategoryTap!(category);
                },
          child: CustomPaint(
            size: size,
            painter: _SankeyPainter(geometry: geometry, styles: styles),
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

class _LinkBand {
  const _LinkBand({required this.from, required this.to, required this.path});

  final _NodeBox from;
  final _NodeBox to;
  final Path path;
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

  void paint(Canvas canvas) {
    final amount = this.amount;
    if (inline) {
      if (alignRight) {
        var right = x;
        if (amount != null) {
          amount.paint(canvas, Offset(right - amount.width, top));
          right -= amount.width + inlineGap;
        }
        name.paint(canvas, Offset(right - name.width, top));
      } else {
        name.paint(canvas, Offset(x, top));
        amount?.paint(canvas, Offset(x + name.width + inlineGap, top));
      }
      return;
    }
    var y = top;
    for (final painter in [name, if (amount != null) amount]) {
      painter.paint(canvas, Offset(alignRight ? x - painter.width : x, y));
      y += painter.height;
    }
  }
}

/// Where everything sits: three columns of nodes, the bands between them
/// and the labels. Heights are proportional to the amounts, with the same
/// scale in every column, and each column is centred vertically so the
/// bands of a short column do not all run downhill.
class _Geometry {
  const _Geometry({
    required this.size,
    required this.sources,
    required this.budget,
    required this.sinks,
    required this.links,
    required this.labels,
  });

  final Size size;
  final List<_NodeBox> sources;
  final _NodeBox budget;
  final List<_NodeBox> sinks;
  final List<_LinkBand> links;
  final List<_PlacedLabel> labels;

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
    _TextStyles text,
  ) {
    final total = diagram.budget.value;
    // Nodes in a column stand a gap apart, unless the window is so short
    // that the gaps would eat the height; then they shrink so that all of
    // them take at most a quarter of it.
    final mostNodes = math.max(diagram.sources.length, diagram.sinks.length);
    final gap = math.min(
      nodeGap,
      0.25 * size.height / math.max(mostNodes - 1, 1),
    );
    double gaps(int count) => math.max(count - 1, 0) * gap;
    final tallestGaps = math.max(
      gaps(diagram.sources.length),
      gaps(diagram.sinks.length),
    );
    final scale =
        total > 0 ? math.max(size.height - tallestGaps, 0) / total : 0.0;
    double nodeHeightOf(double value) =>
        math.max(value * scale, value > 0 ? minNodeHeight : 0);

    List<_NodeBox> column(List<CashFlowNode> nodes, double x) {
      final heights = [for (final n in nodes) nodeHeightOf(n.value)];
      final columnHeight =
          heights.fold(0.0, (sum, h) => sum + h) + gaps(nodes.length);
      var y = (size.height - columnHeight) / 2;
      final boxes = <_NodeBox>[];
      for (var i = 0; i < nodes.length; i++) {
        boxes.add(
          _NodeBox(nodes[i], Rect.fromLTWH(x, y, nodeWidth, heights[i])),
        );
        y += heights[i] + gap;
      }
      return boxes;
    }

    final sources = column(diagram.sources, 0);
    final budget = column([
      diagram.budget,
    ], size.width * budgetFraction - nodeWidth / 2)
        .single;
    final sinks = column(diagram.sinks, size.width - nodeWidth);

    // Bands stack top to bottom on the budget's sides in the nodes' order,
    // at exactly their share of its height; what the inflow leaves
    // uncovered at the bottom is the month's deficit.
    final links = <_LinkBand>[];
    var inY = budget.rect.top;
    for (final source in sources) {
      final h = source.node.value * scale;
      links.add(
        _LinkBand(
          from: source,
          to: budget,
          path: _band(
            source.rect.right,
            source.rect.top,
            source.rect.bottom,
            budget.rect.left,
            inY,
            inY + h,
          ),
        ),
      );
      inY += h;
    }
    var outY = budget.rect.top;
    for (final sink in sinks) {
      final h = sink.node.value * scale;
      links.add(
        _LinkBand(
          from: budget,
          to: sink,
          path: _band(
            budget.rect.right,
            outY,
            outY + h,
            sink.rect.left,
            sink.rect.top,
            sink.rect.bottom,
          ),
        ),
      );
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
    final labels = <_PlacedLabel>[];
    if (leftWidth >= 24) {
      labels.addAll(
        _settle(
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
            size.height),
      );
    }
    if (rightWidth >= 24) {
      labels.addAll([
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
      ].nonNulls);
    }

    return _Geometry(
      size: size,
      sources: sources,
      budget: budget,
      sinks: sinks,
      links: links,
      labels: labels,
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

  /// The category under [point]: its node, its label or its band.
  Category? categoryAt(Offset point) {
    for (final sink in sinks) {
      final category = sink.node.category;
      if (category != null && sink.rect.inflate(6).contains(point)) {
        return category;
      }
    }
    for (final label in labels) {
      final category = label.box.node.category;
      if (category != null && label.rect.inflate(4).contains(point)) {
        return category;
      }
    }
    for (final link in links) {
      final category = link.to.node.category;
      if (category != null && link.path.contains(point)) return category;
    }
    return null;
  }
}

class _SankeyPainter extends CustomPainter {
  const _SankeyPainter({required this.geometry, required this.styles});

  final _Geometry geometry;
  final Map<CashFlowNode, _NodeStyle> styles;

  static const bandAlpha = 0.35;
  static const nodeRadius = Radius.circular(3);

  @override
  void paint(Canvas canvas, Size size) {
    for (final link in geometry.links) {
      final from = styles[link.from.node]!.color;
      final to = styles[link.to.node]!.color;
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(link.from.rect.right, 0),
          Offset(link.to.rect.left, 0),
          [from.withValues(alpha: bandAlpha), to.withValues(alpha: bandAlpha)],
        );
      canvas.drawPath(link.path, paint);
    }
    for (final box in [
      ...geometry.sources,
      geometry.budget,
      ...geometry.sinks,
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(box.rect, nodeRadius),
        Paint()..color = styles[box.node]!.color,
      );
    }
    for (final label in geometry.labels) {
      label.paint(canvas);
    }
  }

  @override
  bool shouldRepaint(_SankeyPainter oldDelegate) =>
      oldDelegate.geometry != geometry || oldDelegate.styles != styles;
}
