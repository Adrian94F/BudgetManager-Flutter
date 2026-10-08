import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../domain/domain.dart';
import '../models/models.dart';
import '../tools/dates.dart';
import 'expenses_list.dart';
import 'widgets/category_style.dart';
import 'widgets/custom_data_table.dart';

/// Category × day grid of the month's expenses, laid out as the iOS table:
/// the days on top, the categories on the left, their sums on the right and
/// two footer rows, the daily (non-recurring) sums and then all expenses
/// where recurring ones make a difference. Today and weekends are tinted down
/// the whole column. Tapping a cell, a day or a category opens the filtered
/// expenses list.
class ExpensesTableView extends StatelessWidget {
  const ExpensesTableView(
      {super.key, required this.data, required this.onOpenFiltered});

  final MonthData data;
  final void Function(ExpensesFilter filter) onOpenFiltered;

  /// Whole amounts; thousands only when the number would not fit a cell.
  static String formatNumber(double number) {
    if (number == 0) return '';
    if (number.abs() < 100000) return number.round().toString();
    return '${(number / 1000).round()}k';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final month = data.month!;
    if (data.categories.isEmpty) return _Message(text: l10n.noCategories);
    if (data.expenses.isEmpty) return _Message(text: l10n.noExpenses);

    final table = ExpenseTable.build(month, data.categories, data.expenses);
    final dayLetters = [
      l10n.shortMonday,
      l10n.shortTuesday,
      l10n.shortWednesday,
      l10n.shortThursday,
      l10n.shortFriday,
      l10n.shortSaturday,
      l10n.shortSunday,
    ];
    final today = Dates.today();
    final todayIndex = table.days.indexWhere((d) => Dates.isSameDay(d, today));

    final grid = CustomDataTable<CellData>(
      // A month of its own scrolls to its own today: no state carried over.
      key: ValueKey(month.id),
      initialColumn: todayIndex < 0 ? null : todayIndex,
      headerLeadingCell: CellData(text: l10n.category, kind: CellKind.header),
      headerTrailingCell: CellData(text: l10n.sum, kind: CellKind.header),
      rowsCells: [
        for (final category in table.categories)
          [
            for (final day in table.days)
              CellData(
                  text: formatNumber(table.cell(category.id, day)),
                  kind: CellKind.value,
                  categoryId: category.id,
                  date: day),
          ],
      ],
      fixedColCells: [
        for (final category in table.categories)
          CellData(
              text: category.name,
              kind: CellKind.category,
              categoryId: category.id),
      ],
      fixedRightColCells: [
        for (final category in table.categories)
          CellData(
              text: formatNumber(table.categoryTotal(category.id)),
              kind: CellKind.categorySum,
              categoryId: category.id),
      ],
      fixedRowCells: [
        for (final day in table.days)
          CellData(
              text: '${day.day}',
              secondaryText: dayLetters[day.weekday - 1],
              kind: CellKind.day,
              date: day),
      ],
      fixedBottomRowsCells: [
        [
          for (final day in table.days)
            CellData(
                text: formatNumber(table.dailyTotal(day)),
                kind: CellKind.footer,
                date: day),
        ],
        // Blank where it would repeat the row above: only the days with
        // recurring expenses show a figure here.
        [
          for (final day in table.days)
            CellData(
                text: table.total(day) == table.dailyTotal(day)
                    ? ''
                    : formatNumber(table.total(day)),
                kind: CellKind.footer,
                date: day),
        ],
      ],
      footerLeadingCells: [
        CellData(text: l10n.sumDaily, kind: CellKind.header),
        CellData(text: l10n.sum, kind: CellKind.header),
      ],
      footerTrailingCells: [
        CellData(
            text: formatNumber(table.grandDaily), kind: CellKind.grandTotal),
        CellData(
            text: table.grandTotal == table.grandDaily
                ? ''
                : formatNumber(table.grandTotal),
            kind: CellKind.grandTotal),
      ],
      cellBuilder: (cell) => _buildCell(context, cell),
    );

    // Clear of the system navigation bar: the body runs under it where the
    // shell has no navigation bar of its own (a wide window), and the sums
    // rows sit at the very bottom. A little room to spare either way.
    final padded = Padding(
      padding: EdgeInsets.only(
        bottom: 8 + MediaQuery.paddingOf(context).bottom,
      ),
      child: grid,
    );

    if (table.outOfRangeCount == 0) return padded;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Material(
          color: scheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: scheme.onTertiaryContainer, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.expensesOutsideMonth(table.outOfRangeCount),
                    style: TextStyle(color: scheme.onTertiaryContainer),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: padded),
      ],
    );
  }

  /// Today down its whole column, header and footers included; weekends in
  /// a neutral gray, as on iOS.
  static Color? _tint(ColorScheme scheme, DateTime? day) {
    if (day == null) return null;
    if (Dates.isSameDay(day, DateTime.now())) {
      return scheme.primary.withValues(alpha: 0.14);
    }
    if (Dates.isWeekend(day)) return Colors.grey.withValues(alpha: 0.08);
    return null;
  }

  ExpensesFilter? _filterFor(CellData cell) => switch (cell.kind) {
        CellKind.header || CellKind.grandTotal => null,
        CellKind.day || CellKind.footer => ExpensesFilter(date: cell.date),
        CellKind.category ||
        CellKind.categorySum =>
          ExpensesFilter(category: cell.categoryId),
        CellKind.value =>
          ExpensesFilter(category: cell.categoryId, date: cell.date),
      };

  Widget _buildCell(BuildContext context, CellData cell) {
    final scheme = Theme.of(context).colorScheme;
    const figures = [FontFeature.tabularFigures()];
    // The header, the footers and the sums on a surface of their own, the
    // body on the plain one, like iOS's secondary and system backgrounds.
    final background = switch (cell.kind) {
      CellKind.category || CellKind.value => scheme.surface,
      _ => scheme.surfaceContainer,
    };

    final Widget content;
    switch (cell.kind) {
      case CellKind.day:
        content = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              cell.text,
              maxLines: 1,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: figures,
                  color: scheme.onSurface),
            ),
            Text(
              cell.secondaryText ?? '',
              maxLines: 1,
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
          ],
        );
      case CellKind.category:
        content = Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: CategoryStyle.of(context, cell.text).accent,
                  shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                cell.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: scheme.onSurface),
              ),
            ),
          ],
        );
      case CellKind.header:
        content = Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            cell.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant),
          ),
        );
      case CellKind.value:
      case CellKind.categorySum:
      case CellKind.footer:
      case CellKind.grandTotal:
        content = Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            cell.text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: TextStyle(
                fontSize: 13,
                fontWeight: cell.kind == CellKind.value
                    ? FontWeight.w400
                    : FontWeight.w600,
                fontFeatures: figures,
                color: scheme.onSurface),
          ),
        );
    }

    final hairline = BorderSide(
        color: scheme.outlineVariant.withValues(alpha: 0.6), width: 0.5);
    final filter = _filterFor(cell);
    return Material(
      color: background,
      child: Ink(
        decoration: BoxDecoration(
          color: _tint(scheme, cell.date),
          border: Border(bottom: hairline, right: hairline),
        ),
        child: InkWell(
          onTap: filter == null ? null : () => onOpenFiltered(filter),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(48.0),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// What a cell of the grid shows, which sets its look and what a tap opens.
enum CellKind {
  /// A label of the header or a footer: "Category", "Sum", "Sum (daily)".
  header,

  /// A day of the header row.
  day,

  /// A category of the leading column.
  category,

  /// One category's expenses of one day.
  value,

  /// A category's total in the trailing column.
  categorySum,

  /// A day's sum in a footer row.
  footer,

  /// The month's sum in a footer's trailing corner.
  grandTotal,
}

/// One cell of the grid: a header (day or category), a sum, or a value.
class CellData {
  const CellData({
    required this.text,
    required this.kind,
    this.secondaryText,
    this.date,
    this.categoryId,
  });

  final String text;
  final CellKind kind;
  final String? secondaryText;
  final DateTime? date;
  final int? categoryId;
}
