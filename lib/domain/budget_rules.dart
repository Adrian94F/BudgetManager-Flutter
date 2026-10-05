import '../models/models.dart';
import '../tools/dates.dart';

/// Small budget rules shared by several screens.
class BudgetRules {
  BudgetRules._();

  /// Categories most used for daily expenses this month, most frequent first;
  /// ties go to the lower id, as in the iOS app. Used for quick selection
  /// when adding an expense.
  static List<int> topCategoryIds(Iterable<Expense> expenses, {int limit = 5}) {
    final counts = <int, int>{};
    for (final expense in expenses) {
      if (expense.isDaily) {
        counts.update(expense.categoryId, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return entries.take(limit).map((e) => e.key).toList();
  }

  /// The dates for a month following [last]: it starts the day after [last]
  /// ends and ends one calendar month after that end date, as the iOS app
  /// and the web app propose.
  static ({DateTime start, DateTime end}) nextMonthRange(Month last) => (
        start: Dates.addDays(last.endDate, 1),
        end: Dates.addMonths(last.endDate, 1),
      );

  /// The dates for a user's very first month: the current calendar month,
  /// as the web onboarding proposes.
  static ({DateTime start, DateTime end}) firstMonthRange({DateTime? today}) {
    final now = today ?? DateTime.now();
    return (
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  /// The default date for a new entry: today, moved inside [month] when
  /// today falls outside it.
  static DateTime defaultEntryDate(Month month, {DateTime? today}) => month.clamp(today ?? DateTime.now());
}
