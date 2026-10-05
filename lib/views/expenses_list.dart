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
/// sit in a collapsed "Incoming" section at the top; a search box narrows the
/// list by category, comment, amount or date.
class ExpensesListView extends StatefulWidget {
  const ExpensesListView({super.key, required this.data, required this.filter, this.onClearFilter});

  final MonthData data;
  final ExpensesFilter filter;

  /// Called when the user dismisses the filter chip.
  final VoidCallback? onClearFilter;

  @override
  State<ExpensesListView> createState() => _ExpensesListViewState();
}

class _ExpensesListViewState extends State<ExpensesListView> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isSearching => _query.trim().isNotEmpty;

  List<Expense> _applyFilter(List<Expense> expenses) {
    final filter = widget.filter;
    return expenses.where((e) {
      if (filter.date != null && !Dates.isSameDay(e.date, filter.date!)) return false;
      if (filter.category != null && e.categoryId != filter.category) return false;
      return true;
    }).toList();
  }

  List<Expense> _applySearch(List<Expense> expenses, String locale) {
    if (!_isSearching) return expenses;
    final query = _query.trim().toLowerCase();
    final shortDate = DateFormat.yMMMd(locale);
    final longDate = DateFormat.yMMMMEEEEd(locale);
    return expenses.where((e) {
      final haystack = [
        widget.data.categoryName(e.categoryId),
        e.comment ?? '',
        Formatters.money(e.value, locale),
        e.value.toStringAsFixed(2),
        shortDate.format(e.date),
        longDate.format(e.date),
      ].join('\n').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  String _filterLabel(String locale) {
    final parts = [
      if (widget.filter.date != null) DateFormat.yMMMd(locale).format(widget.filter.date!),
      if (widget.filter.category != null) widget.data.categoryName(widget.filter.category!),
    ];
    return parts.join(' · ');
  }

  Future<void> _edit(Expense expense) => ExpenseFormScreen.open(context, expense: expense);

  Future<void> _copy(Expense expense) => ExpenseFormScreen.open(context, template: expense);

  Future<void> _confirmDelete(Expense expense) async {
    final l10n = AppLocalizations.of(context)!;
    final months = AppScope.of(context).months;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.alert),
        content: Text(l10n.expenseRemoval),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await months.deleteExpense(expense.id);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeApiError(e, l10n))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final today = Dates.today();

    final sorted = _applySearch(_applyFilter(widget.data.expenses), locale)
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });
    final separateIncoming = !_isSearching && widget.filter.date == null;
    final incoming = separateIncoming ? sorted.where((e) => e.date.isAfter(today)).toList() : const <Expense>[];
    final current = separateIncoming ? sorted.where((e) => !e.date.isAfter(today)).toList() : sorted;

    return Column(
      children: [
        if (widget.filter.isActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                avatar: const Icon(Icons.filter_alt_outlined, size: 18),
                label: Text(_filterLabel(locale)),
                tooltip: l10n.filteredExpenses,
                onDeleted: widget.onClearFilter,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SearchBar(
              controller: _searchController,
              hintText: l10n.searchExpenses,
              leading: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.search)),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
              ],
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
        Expanded(child: _buildList(context, l10n, locale, today, incoming, current)),
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
              _isSearching ? l10n.noResults : l10n.noExpenses,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
          for (final expense in incoming) _expenseTile(expense, showDate: true, locale: locale),
        ],
      ));
    }
    DateTime? lastDay;
    for (final expense in current) {
      if (lastDay == null || !Dates.isSameDay(lastDay, expense.date)) {
        lastDay = expense.date;
        items.add(DayHeader(label: dayLabel(expense.date, today, l10n, locale)));
      }
      items.add(_expenseTile(expense, showDate: false, locale: locale));
    }
    return ListView(padding: const EdgeInsets.only(bottom: 88), children: items);
  }

  Widget _expenseTile(Expense expense, {required bool showDate, required String locale}) {
    return _ExpenseTile(
      key: ValueKey(expense.id),
      expense: expense,
      categoryName: widget.data.categoryName(expense.categoryId),
      dateLabel: showDate ? DateFormat.MMMEd(locale).format(expense.date) : null,
      onEdit: () => _edit(expense),
      onCopy: () => _copy(expense),
      onDelete: () => _confirmDelete(expense),
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
  final VoidCallback onDelete;

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
        title: Row(
          children: [
            if (expense.isMonthly) ...[
              Icon(Icons.repeat_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
            ],
            Expanded(child: Text(categoryName, maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 12),
            Text(
              Formatters.moneyOf(context, expense.value),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        subtitle: subtitleParts.isEmpty
            ? null
            : Text(
                subtitleParts.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
      ),
    );
  }
}
