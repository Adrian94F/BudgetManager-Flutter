import 'category.dart';
import 'currency.dart';
import 'expense.dart';
import 'income.dart';
import 'money.dart';
import 'month.dart';

/// The `GET api/month/` response: every month of the user, the categories,
/// and one month with its incomes and expenses.
///
/// When the user has no months yet the server answers with `message` and
/// without `month`, `incomes` or `expenses`; [month] is then null.
class MonthData {
  /// All months, newest first.
  final List<Month> months;

  /// Categories ordered by position.
  final List<Category> categories;
  final Month? month;
  final List<Income> incomes;
  final List<Expense> expenses;

  /// The user's planned savings as the server stores it. It applies only to
  /// the current month; see `BudgetMath.effectivePlannedSavings`.
  final double plannedSavings;

  /// ISO 4217 code of the user's currency; every amount is in it.
  final String currency;
  final String? message;

  const MonthData({
    required this.months,
    required this.categories,
    this.month,
    this.incomes = const [],
    this.expenses = const [],
    this.plannedSavings = 0,
    this.currency = defaultCurrency,
    this.message,
  });

  factory MonthData.fromJson(Map<String, dynamic> json) {
    final months = (json['months'] as List<dynamic>? ?? const [])
        .map((m) => Month.fromJson(m as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    final categories = (json['categories'] as List<dynamic>? ?? const [])
        .map((c) => Category.fromJson(c as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final monthJson = json['month'] as Map<String, dynamic>?;
    final month = monthJson == null ? null : Month.fromJson(monthJson);
    final incomes = month == null
        ? <Income>[]
        : (json['incomes'] as List<dynamic>? ?? const [])
            .map((i) => Income.fromJson(i as Map<String, dynamic>,
                fallbackDate: month.startDate))
            .toList();
    final expenses = (json['expenses'] as List<dynamic>? ?? const [])
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
    return MonthData(
      months: months,
      categories: categories,
      month: month,
      incomes: incomes,
      expenses: expenses,
      plannedSavings: parseMoney(json['planned_savings']),
      currency: json['currency'] as String? ?? defaultCurrency,
      message: json['message'] as String?,
    );
  }

  bool get hasMonth => month != null;

  Month? monthById(int id) {
    for (final m in months) {
      if (m.id == id) return m;
    }
    return month?.id == id ? month : null;
  }

  Category? categoryById(int id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  String categoryName(int id, {String fallback = '–'}) =>
      categoryById(id)?.name ?? fallback;

  /// The month whose dates contain [today], if any.
  Month? currentMonth([DateTime? today]) {
    final now = today ?? DateTime.now();
    for (final m in months) {
      if (m.contains(now)) return m;
    }
    return null;
  }

  MonthData copyWith({
    List<Month>? months,
    List<Category>? categories,
    Month? month,
    List<Income>? incomes,
    List<Expense>? expenses,
    double? plannedSavings,
    String? currency,
    String? message,
  }) =>
      MonthData(
        months: months ?? this.months,
        categories: categories ?? this.categories,
        month: month ?? this.month,
        incomes: incomes ?? this.incomes,
        expenses: expenses ?? this.expenses,
        plannedSavings: plannedSavings ?? this.plannedSavings,
        currency: currency ?? this.currency,
        message: message ?? this.message,
      );
}
