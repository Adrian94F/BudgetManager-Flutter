import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../api/api.dart';
import '../app/app_scope.dart';
import '../models/models.dart';
import '../tools/dates.dart';
import '../tools/formatters.dart';
import 'income_form.dart';
import 'widgets/day_header.dart';
import 'widgets/error_views.dart';

/// The month's incomes grouped by day, newest first. An income the server
/// sent without a date shows under the month's start date.
class IncomesScreen extends StatelessWidget {
  const IncomesScreen({super.key, required this.data});

  final MonthData data;

  Future<void> _confirmDelete(BuildContext context, Income income) async {
    final l10n = AppLocalizations.of(context)!;
    final months = AppScope.of(context).months;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.alert),
        content: Text(l10n.incomeRemoval),
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
      await months.deleteIncome(income.id);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeApiError(e, l10n))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    final today = Dates.today();

    final incomes = [...data.incomes]
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });

    if (incomes.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(48.0),
            child: Text(
              l10n.noIncomes,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      );
    }

    final items = <Widget>[];
    DateTime? lastDay;
    for (final income in incomes) {
      if (lastDay == null || !Dates.isSameDay(lastDay, income.date)) {
        lastDay = income.date;
        items.add(DayHeader(label: dayLabel(income.date, today, l10n, locale)));
      }
      items.add(_IncomeTile(
        key: ValueKey(income.id),
        income: income,
        onEdit: () => IncomeFormScreen.open(context, income: income),
        onCopy: () => IncomeFormScreen.open(context, template: income),
        onDelete: () => _confirmDelete(context, income),
      ));
    }
    return ListView(padding: const EdgeInsets.only(bottom: 88), children: items);
  }
}

class _IncomeTile extends StatelessWidget {
  const _IncomeTile({
    super.key,
    required this.income,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
  });

  final Income income;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final comment = income.comment;

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
        leading: Icon(
          income.isSalary ? Icons.work_outline_rounded : Icons.savings_outlined,
          color: income.isSalary ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Row(
          children: [
            Expanded(child: Text(income.isSalary ? l10n.salary : l10n.otherIncome)),
            const SizedBox(width: 12),
            Text(
              Formatters.currencyFormatter.format(income.value),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        subtitle: comment == null || comment.isEmpty
            ? null
            : Text(
                comment,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
      ),
    );
  }
}
