import '../tools/dates.dart';
import 'money.dart';

class Income {
  final int id;
  final double value;

  /// The income's date; the month's start date when the server sent none.
  final DateTime date;

  /// False when the server sent a null date and [date] is the fallback.
  final bool hasDate;
  final String? comment;
  final bool isSalary;

  const Income({
    required this.id,
    required this.value,
    required this.date,
    this.hasDate = true,
    this.comment,
    required this.isSalary,
  });

  /// [fallbackDate] replaces a missing date, as the iOS app does with the
  /// month's start date.
  factory Income.fromJson(Map<String, dynamic> json,
      {required DateTime fallbackDate}) {
    final parsed = Dates.tryParseApi(json['date'] as String?);
    return Income(
      id: json['id'] as int,
      value: parseMoney(json['value']),
      date: parsed ?? Dates.dateOnly(fallbackDate),
      hasDate: parsed != null,
      comment: json['comment'] as String?,
      isSalary: json['is_salary'] == true,
    );
  }

  Income copyWith(
          {double? value, DateTime? date, String? comment, bool? isSalary}) =>
      Income(
        id: id,
        value: value ?? this.value,
        date: date ?? this.date,
        hasDate: date != null || hasDate,
        comment: comment ?? this.comment,
        isSalary: isSalary ?? this.isSalary,
      );

  @override
  String toString() =>
      'Income($id, $value, ${Dates.formatApi(date)}, salary: $isSalary)';
}
