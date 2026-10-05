import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../models/models.dart';

/// Bottom sheet listing every month, newest first and grouped by year. The
/// month on screen carries a check mark, the month containing today a
/// calendar icon.
class MonthPickerSheet extends StatelessWidget {
  const MonthPickerSheet({
    super.key,
    required this.months,
    required this.selectedId,
    required this.onSelect,
    required this.onCreate,
  });

  final List<Month> months;
  final int? selectedId;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;

  static Future<void> show(
    BuildContext context, {
    required List<Month> months,
    required int? selectedId,
    required ValueChanged<int> onSelect,
    required VoidCallback onCreate,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => MonthPickerSheet(
        months: months,
        selectedId: selectedId,
        onSelect: onSelect,
        onCreate: onCreate,
      ),
    );
  }

  static const _rowHeight = 72.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final today = DateTime.now();
    final selectedIndex = months.indexWhere((m) => m.id == selectedId);
    final initialOffset =
        selectedIndex > 2 ? (selectedIndex - 1) * _rowHeight : 0.0;

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                    child: Text(l10n.selectMonth,
                        style: theme.textTheme.titleLarge)),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.pop(context);
                    onCreate();
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.newMonth),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              controller: ScrollController(initialScrollOffset: initialOffset),
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: months.length,
              itemBuilder: (context, index) {
                final month = months[index];
                final year = month.startDate.year;
                final showYearHeader =
                    index == 0 || months[index - 1].startDate.year != year;
                final isSelected = month.id == selectedId;
                final isToday = month.contains(today);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showYearHeader)
                      Padding(
                        padding:
                            EdgeInsets.fromLTRB(24, index == 0 ? 4 : 16, 24, 4),
                        child: Text(
                          '$year',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(color: theme.colorScheme.primary),
                        ),
                      ),
                    ListTile(
                      selected: isSelected,
                      leading: Icon(isToday
                          ? Icons.today_rounded
                          : Icons.calendar_month_outlined),
                      title: Text(
                          month.title(locale, today: DateTime(year, 1, 1))),
                      subtitle: Text(month.rangeTitle(locale)),
                      trailing:
                          isSelected ? const Icon(Icons.check_rounded) : null,
                      onTap: () {
                        Navigator.pop(context);
                        onSelect(month.id);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
