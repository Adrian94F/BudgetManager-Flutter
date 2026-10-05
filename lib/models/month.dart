import 'package:intl/intl.dart';

import '../tools/dates.dart';

/// A billing period with arbitrary start and end dates, named after the
/// month its start date falls in.
class Month {
  final int id;
  final DateTime startDate;
  final DateTime endDate;

  const Month({
    required this.id,
    required this.startDate,
    required this.endDate,
  });

  factory Month.fromJson(Map<String, dynamic> json) => Month(
        id: json['id'] as int,
        startDate: Dates.parseApi(json['start_date'] as String),
        endDate: Dates.parseApi(json['end_date'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'start_date': Dates.formatApi(startDate),
        'end_date': Dates.formatApi(endDate),
      };

  int get lengthInDays => Dates.daysBetween(startDate, endDate) + 1;

  bool contains(DateTime day) {
    final d = Dates.dateOnly(day);
    return !d.isBefore(startDate) && !d.isAfter(endDate);
  }

  /// Whether [today] falls inside this month (Django's `Month.is_actual()`).
  bool isActual([DateTime? today]) => contains(today ?? DateTime.now());

  /// Days from [today] to the end date, today included; never negative.
  int daysLeft([DateTime? today]) {
    final left =
        Dates.daysBetween(Dates.dateOnly(today ?? DateTime.now()), endDate) + 1;
    return left < 0 ? 0 : left;
  }

  /// [day] moved inside the month when it falls outside it.
  DateTime clamp(DateTime day) {
    final d = Dates.dateOnly(day);
    if (d.isBefore(startDate)) return startDate;
    if (d.isAfter(endDate)) return endDate;
    return d;
  }

  /// Month name of the start date with a capital first letter; the year is
  /// appended when it differs from the current one, e.g. "Październik 2025".
  String title(String locale, {DateTime? today}) {
    final now = today ?? DateTime.now();
    final format = startDate.year == now.year
        ? DateFormat.MMMM(locale)
        : DateFormat.yMMMM(locale);
    return _capitalize(format.format(startDate));
  }

  /// Human readable range, e.g. "26 – 25 Apr 2026" or "26 Sep – 25 Oct 2026".
  String rangeTitle(String locale) {
    final sameYear = startDate.year == endDate.year;
    final sameMonth = sameYear && startDate.month == endDate.month;
    final end = DateFormat.yMMMd(locale).format(endDate);
    if (sameMonth) {
      return '${DateFormat.d(locale).format(startDate)} – $end';
    }
    if (sameYear) {
      return '${DateFormat.MMMd(locale).format(startDate)} – $end';
    }
    return '${DateFormat.yMMMd(locale).format(startDate)} – $end';
  }

  static String _capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  @override
  bool operator ==(Object other) =>
      other is Month &&
      other.id == id &&
      other.startDate == startDate &&
      other.endDate == endDate;

  @override
  int get hashCode => Object.hash(id, startDate, endDate);

  @override
  String toString() =>
      'Month($id, ${Dates.formatApi(startDate)}..${Dates.formatApi(endDate)})';
}
