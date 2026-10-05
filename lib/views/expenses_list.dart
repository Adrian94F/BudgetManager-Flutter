import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../api/api.dart';
import '../app/app_scope.dart';
import '../models/models.dart';
import '../tools/dates.dart';
import '../tools/formatters.dart';
import 'expense_form.dart';
import 'widgets/category_style.dart';
import 'widgets/day_header.dart';
import 'widgets/error_views.dart';

/// A day and/or category narrowing the list, set from the expenses table.
class ExpensesFilter {
  const ExpensesFilter({this.date, this.category});

  final DateTime? date;
  final int? category;

  bool get isActive => date != null || category != null;
}

/// The month's expenses grouped by day, newest first. Future-dated expenses
/// sit in a collapsed "Incoming" section at the top. Search lives in the top
/// bar (see `ExpenseSearchButton`).
class ExpensesListView extends StatelessWidget {
  const ExpensesListView({
    super.key,
    required this.data,
    required this.filter,
    this.onClearFilter,
    this.showFilterChip = true,
  });

  final MonthData data;
  final ExpensesFilter filter;

  /// Called when the user dismisses the filter chip.
  final VoidCallback? onClearFilter;

  /// Whether an active filter shows as a chip above the list; false where
  /// the screen names the filter itself.
  final bool showFilterChip;

  List<Expense> _applyFilter(List<Expense> expenses) {
    return expenses.where((e) {
      if (filter.date != null && !Dates.isSameDay(e.date, filter.date!)) {
        return false;
      }
      if (filter.category != null && e.categoryId != filter.category) {
        return false;
      }
      return true;
    }).toList();
  }

  String _filterLabel(String locale) {
    final parts = [
      if (filter.date != null) DateFormat.yMMMd(locale).format(filter.date!),
      if (filter.category != null) data.categoryName(filter.category!),
    ];
    return parts.join(' · ');
  }

  /// Deletes on the server and offers Undo, which re-creates the expense in
  /// the month it came from (it gets a new id). Returns whether the row may
  /// be dismissed, so a failed delete leaves the row in place.
  Future<bool> _delete(BuildContext context, Expense expense) async {
    final l10n = AppLocalizations.of(context)!;
    final services = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final monthId = data.month!.id;
    try {
      await services.months.deleteExpense(expense.id);
    } on ApiException catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text(describeApiError(e, l10n))));
      return false;
    }
    messenger.showSnackBar(SnackBar(
      content: Text(l10n.expenseDeleted),
      action: SnackBarAction(
        label: l10n.undo,
        onPressed: () async {
          try {
            await services.api.createExpense(
              monthId: monthId,
              value: expense.value,
              date: expense.date,
              categoryId: expense.categoryId,
              comment: expense.comment ?? '',
              isMonthly: expense.isMonthly,
            );
            await services.months.refresh();
          } on ApiException catch (e) {
            messenger.showSnackBar(
                SnackBar(content: Text(describeApiError(e, l10n))));
          }
        },
      ),
    ));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final today = Dates.today();

    final sorted = _applyFilter(data.expenses)
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });
    final separateIncoming = filter.date == null;
    final incoming = separateIncoming
        ? sorted.where((e) => e.date.isAfter(today)).toList()
        : const <Expense>[];
    final current = separateIncoming
        ? sorted.where((e) => !e.date.isAfter(today)).toList()
        : sorted;

    return Column(
      children: [
        if (filter.isActive && showFilterChip)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                avatar: const Icon(Icons.filter_alt_outlined, size: 18),
                label: Text(_filterLabel(locale)),
                tooltip: l10n.filteredExpenses,
                onDeleted: onClearFilter,
              ),
            ),
          ),
        Expanded(
            child: _buildList(context, l10n, locale, today, incoming, current)),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    AppLocalizations l10n,
    String locale,
    DateTime today,
    List<Expense> incoming,
    List<Expense> current,
  ) {
    if (incoming.isEmpty && current.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(48.0),
            child: Text(
              l10n.noExpenses,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      );
    }

    final items = <Widget>[];
    if (incoming.isNotEmpty) {
      items.add(ExpansionTile(
        leading: const Icon(Icons.schedule_rounded),
        title: Text(l10n.incomingExpenses(incoming.length)),
        children: [
          for (final expense in incoming)
            _expenseTile(context, expense, showDate: true, locale: locale),
        ],
      ));
    }
    DateTime? lastDay;
    for (final expense in current) {
      if (lastDay == null || !Dates.isSameDay(lastDay, expense.date)) {
        lastDay = expense.date;
        items
            .add(DayHeader(label: dayLabel(expense.date, today, l10n, locale)));
      }
      items
          .add(_expenseTile(context, expense, showDate: false, locale: locale));
    }
    return ListView(
        padding:
            EdgeInsets.only(bottom: 88 + MediaQuery.paddingOf(context).bottom),
        children: items);
  }

  Widget _expenseTile(BuildContext context, Expense expense,
      {required bool showDate, required String locale}) {
    return _ExpenseTile(
      key: ValueKey(expense.id),
      expense: expense,
      categoryName: data.categoryName(expense.categoryId),
      dateLabel:
          showDate ? DateFormat.MMMEd(locale).format(expense.date) : null,
      onEdit: () => ExpenseFormScreen.open(context, expense: expense),
      onCopy: () => ExpenseFormScreen.open(context, template: expense),
      onDelete: () => _delete(context, expense),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    super.key,
    required this.expense,
    required this.categoryName,
    required this.dateLabel,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
  });

  final Expense expense;
  final String categoryName;
  final String? dateLabel;
  final VoidCallback onEdit;
  final VoidCallback onCopy;

  /// Deletes the expense; returns whether the row may go.
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final comment = expense.comment;
    final subtitleParts = [
      if (dateLabel != null) dateLabel!,
      if (comment != null && comment.isNotEmpty) comment,
    ];

    return Slidable(
      key: key,
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.5,
        // A full swipe deletes once the server confirmed; a partial swipe
        // shows Copy and Remove.
        dismissible:
            DismissiblePane(confirmDismiss: onDelete, onDismissed: () {}),
        children: [
          SlidableAction(
            onPressed: (_) => onCopy(),
            backgroundColor: scheme.secondaryContainer,
            foregroundColor: scheme.onSecondaryContainer,
            icon: Icons.content_copy_rounded,
            label: l10n.copy,
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: scheme.errorContainer,
            foregroundColor: scheme.onErrorContainer,
            icon: Icons.delete_outline_rounded,
            label: l10n.remove,
          ),
        ],
      ),
      child: ListTile(
        onTap: onEdit,
        leading: CategoryAvatar(name: categoryName),
        title: Row(
          children: [
            if (expense.isMonthly) ...[
              Icon(Icons.repeat_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
            ],
            Expanded(
                child: Text(categoryName,
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 12),
            Text(
              Formatters.moneyOf(context, expense.value),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        subtitle: subtitleParts.isEmpty
            ? null
            : Text(
                subtitleParts.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
      ),
    );
  }
}
