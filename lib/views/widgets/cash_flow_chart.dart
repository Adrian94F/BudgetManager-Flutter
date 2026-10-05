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
/// leftover the "saved" green. Every node has a label with its amount, in
/// the node's colour: on the roomy right side name and amount share one
/// line, on the left the amount goes under the name. Labels of small nodes
/// move down rather than overlap. A tap on a category (its node, label or
/// band) calls [onCategoryTap].
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
              final style => (style.accent, style.onContainer),
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
        amount: Formatters.moneyOf(context, node.value),
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

  /// The node's name in its label, so the label reads as the node's even
  /// when it had to move away from it.
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
/// it; otherwise the amount goes under the name.
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
  static const nodeGap = 8.0;
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
    double gaps(int count) => math.max(count - 1, 0) * nodeGap;
    final tallestGaps = math.max(
      gaps(diagram.sources.length),
      gaps(diagram.sinks.length),
    );
    final scale =
        total > 0 ? math.max(size.height - tallestGaps, 0) / total : 0.0;
    double heightOf(double value) =>
        math.max(value * scale, value > 0 ? minNodeHeight : 0);

    List<_NodeBox> column(List<CashFlowNode> nodes, double x) {
      final heights = [for (final n in nodes) heightOf(n.value)];
      final columnHeight =
          heights.fold(0.0, (sum, h) => sum + h) + gaps(nodes.length);
      var y = (size.height - columnHeight) / 2;
      final boxes = <_NodeBox>[];
      for (var i = 0; i < nodes.length; i++) {
        boxes.add(
          _NodeBox(nodes[i], Rect.fromLTWH(x, y, nodeWidth, heights[i])),
        );
        y += heights[i] + nodeGap;
      }
      return boxes;
    }

    final sources = column(diagram.sources, 0);
    final budget = column([
      diagram.budget,
    ], size.width * budgetFraction - nodeWidth / 2)
        .single;
    final sinks = column(diagram.sinks, size.width - nodeWidth);

    // Bands stack top to bottom on the budget's sides in the nodes' order;
    // what the inflow leaves uncovered at the bottom is the month's deficit.
    final links = <_LinkBand>[];
    var inY = budget.rect.top;
    for (final source in sources) {
      final h = heightOf(source.node.value);
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
      final h = heightOf(sink.node.value);
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

    // Labels. The sources' labels (right of their nodes) and the budget's
    // (left of its node, at the top, since the node spans the height) share
    // the narrow left side, so they are placed together and keep out of
    // each other's way. The sinks' labels have the wide right side.
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
        _settle([
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
        ], size.height),
      );
    }
    if (rightWidth >= 24) {
      labels.addAll(
        _settle([
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
        ], size.height),
      );
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

  /// A node's label laid out to fit [maxWidth], at [top] or else centred on
  /// its node. Inline, the amount is measured first and the name gets what
  /// is left; when that is next to nothing the amount goes under the name
  /// after all.
  static _PlacedLabel _label(
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
    TextPainter? amount;
    TextPainter? name;
    if (inline) {
      final inlineAmount = _layout(
        style.amount,
        text.amountInline,
        null,
        text,
        maxWidth,
      );
      final nameWidth = maxWidth - inlineAmount.width - _PlacedLabel.inlineGap;
      if (nameWidth >= 40) {
        amount = inlineAmount;
        name =
            _layout(style.name, text.name, style.labelColor, text, nameWidth);
      } else {
        inline = false;
      }
    }
    name ??= _layout(style.name, text.name, style.labelColor, text, maxWidth);
    amount ??= _layout(style.amount, text.amountBelow, null, text, maxWidth);
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

  /// Keeps one side's labels apart: in order from the top, a label that
  /// would overlap the one above moves down, and the whole run moves back
  /// up when the last one would run off the bottom. When even stacked
  /// tightly they do not fit (a short window with many small categories),
  /// the smallest nodes go without a label; they stay tappable.
  static List<_PlacedLabel> _settle(List<_PlacedLabel> labels, double height) {
    double needed() =>
        labels.fold(0.0, (sum, l) => sum + l.height) +
        math.max(labels.length - 1, 0) * labelSpacing;
    while (labels.length > 1 && needed() > height) {
      labels.remove(
        labels.reduce(
          (a, b) => a.box.node.value <= b.box.node.value ? a : b,
        ),
      );
    }
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
    return labels;
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
