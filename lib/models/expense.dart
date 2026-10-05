import '../tools/dates.dart';
import 'money.dart';

class Expense {
  final int id;
  final double value;
  final DateTime date;
  final String? comment;
  final int categoryId;

  /// A recurring (monthly) expense; left out of the daily figures.
  final bool isMonthly;

  const Expense({
    required this.id,
    required this.value,
    required this.date,
    this.comment,
    required this.categoryId,
    required this.isMonthly,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as int,
        value: parseMoney(json['value']),
        date: Dates.parseApi(json['date'] as String),
        comment: json['comment'] as String?,
        categoryId: json['category'] as int,
        isMonthly: json['is_monthly'] == true,
      );

  bool get isDaily => !isMonthly;

  Expense copyWith(
          {double? value,
          DateTime? date,
          String? comment,
          int? categoryId,
          bool? isMonthly}) =>
      Expense(
        id: id,
        value: value ?? this.value,
        date: date ?? this.date,
        comment: comment ?? this.comment,
        categoryId: categoryId ?? this.categoryId,
        isMonthly: isMonthly ?? this.isMonthly,
      );

  @override
  String toString() =>
      'Expense($id, $value, ${Dates.formatApi(date)}, category $categoryId, monthly: $isMonthly)';
}
