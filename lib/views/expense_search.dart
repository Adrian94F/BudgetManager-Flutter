import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../models/models.dart';
import '../tools/formatters.dart';
import 'expense_form.dart';
import 'widgets/category_style.dart';

/// Whether [expense] matches a search [query]: by category name, comment,
/// amount (formatted or raw) or date (short or long form).
bool expenseMatches(Expense expense, String query, MonthData data, String locale) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  final haystack = [
    data.categoryName(expense.categoryId),
    expense.comment ?? '',
    Formatters.money(expense.value, locale),
    expense.value.toStringAsFixed(2),
    DateFormat.yMMMd(locale).format(expense.date),
    DateFormat.yMMMMEEEEd(locale).format(expense.date),
  ].join('\n').toLowerCase();
  return haystack.contains(needle);
}

/// Magnifier in the top bar that opens Material's full-screen search view
/// over the month's expenses; tapping a result opens it for editing.
class ExpenseSearchButton extends StatelessWidget {
  const ExpenseSearchButton({super.key, required this.data});

  final MonthData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hostContext = context;
    return SearchAnchor(
      viewHintText: l10n.searchExpenses,
      builder: (context, controller) => IconButton(
        icon: const Icon(Icons.search),
        tooltip: l10n.searchExpenses,
        onPressed: controller.openView,
      ),
      suggestionsBuilder: (context, controller) {
        final query = controller.text.trim();
        if (query.isEmpty) return const <Widget>[];
        final locale = Localizations.localeOf(context).toString();
        final matches = data.expenses.where((e) => expenseMatches(e, query, data, locale)).toList()
          ..sort((a, b) {
            final byDate = b.date.compareTo(a.date);
            return byDate != 0 ? byDate : b.id.compareTo(a.id);
          });
        if (matches.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                l10n.noResults,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ];
        }
        return [
          for (final expense in matches)
            _ResultTile(
              expense: expense,
              categoryName: data.categoryName(expense.categoryId),
              locale: locale,
              onTap: () {
                controller.closeView(null);
                ExpenseFormScreen.open(hostContext, expense: expense);
              },
            ),
        ];
      },
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.expense, required this.categoryName, required this.locale, required this.onTap});

  final Expense expense;
  final String categoryName;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comment = expense.comment;
    final subtitle = [
      DateFormat.yMMMd(locale).format(expense.date),
      if (comment != null && comment.isNotEmpty) comment,
    ].join(' · ');
    return ListTile(
      leading: CategoryAvatar(name: categoryName),
      title: Row(
        children: [
          if (expense.isMonthly) ...[
            Icon(Icons.repeat_rounded, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
          ],
          Expanded(child: Text(categoryName, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 12),
          Text(
            Formatters.money(expense.value, locale),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}
