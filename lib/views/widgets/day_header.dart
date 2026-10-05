import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../../tools/dates.dart';

/// "Today", "Yesterday", or the weekday and date, with the year when it is
/// not the current one.
String dayLabel(
    DateTime day, DateTime today, AppLocalizations l10n, String locale) {
  if (Dates.isSameDay(day, today)) return l10n.today;
  if (Dates.isSameDay(day, Dates.addDays(today, -1))) return l10n.yesterday;
  final format = day.year == today.year
      ? DateFormat.MMMMEEEEd(locale)
      : DateFormat.yMMMMEEEEd(locale);
  final text = format.format(day);
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

/// Section header of a day in the expenses and incomes lists.
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
