import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../../tools/dates.dart';

/// "Today" and "Yesterday" under the date field of the expense and income
/// forms, as in the iOS app and on the web: most entries are for one of the
/// two days, and a chip is one tap where the date picker is three. The chip
/// of the day [selected] falls on shows selected; any other date leaves both
/// unselected.
class QuickDateChips extends StatelessWidget {
  const QuickDateChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = Dates.today();
    Widget chip(String label, DateTime day) => ChoiceChip(
          label: Text(label),
          selected: Dates.isSameDay(selected, day),
          onSelected: enabled ? (_) => onSelected(day) : null,
        );
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: [
        chip(l10n.dateToday, now),
        chip(l10n.yesterday, Dates.addDays(now, -1)),
      ],
    );
  }
}
