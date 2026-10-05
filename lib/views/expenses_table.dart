import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../domain/domain.dart';
import '../models/models.dart';
import '../tools/dates.dart';
import 'expenses_list.dart';
import 'widgets/category_style.dart';
import 'widgets/custom_data_table.dart';

/// Category × day grid of the month's expenses with a sum row and column.
/// Tapping a cell, a day or a category opens the filtered expenses list.
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

    final grid = CustomDataTable<CellData>(
      rowsCells: [
        for (final category in table.categories)
          [
            for (final day in table.days)
              CellData(
                  text: formatNumber(table.cell(category.id, day)),
                  categoryId: category.id,
                  date: day),
          ],
      ],
      fixedColCells: [
        for (final category in table.categories)
          CellData(text: category.name, categoryId: category.id),
      ],
      fixedRightColCells: [
        for (final category in table.categories)
          CellData(
              text: formatNumber(table.categoryTotal(category.id)),
              categoryId: category.id,
              isSum: true),
      ],
      fixedRowCells: [
        for (final day in table.days)
          CellData(
              text: '${day.day}',
              secondaryText: dayLetters[day.weekday - 1],
              date: day),
      ],
      fixedBottomRowCells: [
        for (final day in table.days)
          CellData(
              text: formatNumber(table.total(day)), date: day, isSum: true),
      ],
      cellBuilder: (cell) => _buildCell(context, cell),
    );

    // Clear of the system navigation bar: the body runs under it where the
    // shell has no navigation bar of its own (a wide window), and the sums
    // row sits at the very bottom. A little room to spare either way.
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

  Widget _buildCell(BuildContext context, CellData? cell) {
    if (cell == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final category = cell.categoryId;
    final day = cell.date;

    // Header row: day number with its weekday letter; today gets a filled circle.
    if (category == null && day != null && !cell.isSum) {
      final isToday = Dates.isSameDay(day, DateTime.now());
      final isWeekend = Dates.isWeekend(day);
      final accent = isWeekend ? scheme.primary : scheme.onSurfaceVariant;
      return Material(
        color: isToday ? scheme.primaryContainer : scheme.surface,
        child: InkWell(
          onTap: () => onOpenFiltered(ExpensesFilter(date: day)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                cell.secondaryText ?? '',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isWeekend ? FontWeight.w600 : FontWeight.w500,
                  color: isToday ? scheme.onPrimaryContainer : accent,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isToday ? scheme.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    cell.text,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      color: isToday
                          ? scheme.onPrimary
                          : (isWeekend ? scheme.primary : scheme.onSurface),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Category column.
    if (day == null && category != null && !cell.isSum) {
      return Material(
        color: scheme.surface,
        child: InkWell(
          onTap: () => onOpenFiltered(ExpensesFilter(category: category)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: Row(
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
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                        color: scheme.onSurface),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Sum cells: a category's total, or a day's total.
    if (cell.isSum) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              onOpenFiltered(ExpensesFilter(category: category, date: day)),
          child: Center(
            child: cell.text.isEmpty
                ? null
                : Text(
                    cell.text,
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant),
                  ),
          ),
        ),
      );
    }

    // Category × day cell.
    final Color background;
    if (Dates.isSameDay(day!, DateTime.now())) {
      background = scheme.primaryContainer.withValues(alpha: 0.3);
    } else if (Dates.isWeekend(day)) {
      background = scheme.surfaceContainerHighest.withValues(alpha: 0.3);
    } else {
      background = Colors.transparent;
    }
    return Material(
      color: background,
      child: InkWell(
        onTap: () =>
            onOpenFiltered(ExpensesFilter(category: category, date: day)),
        child: Center(
          child: cell.text.isEmpty
              ? null
              : Text(
                  cell.text,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface),
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

/// One cell of the grid: a header (day or category), a sum, or a value.
class CellData {
  const CellData({
    required this.text,
    this.secondaryText,
    this.date,
    this.categoryId,
    this.isSum = false,
  });

  final String text;
  final String? secondaryText;
  final DateTime? date;
  final int? categoryId;
  final bool isSum;
}
