/// Helpers for the API's bare `yyyy-MM-dd` dates.
///
/// Dates are handled as local midnight. Arithmetic goes through the calendar
/// fields instead of [Duration], so a daylight-saving change never shifts a
/// day (the old table code lost a sum row on the DST weekend for that reason).
class Dates {
  Dates._();

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime today() => dateOnly(DateTime.now());

  static DateTime addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  /// Adds whole months, clamping the day to the target month's length
  /// (Jan 31 + 1 month = Feb 28), as Foundation's Calendar and dateutil do.
  static DateTime addMonths(DateTime date, int months) {
    final total = date.year * 12 + (date.month - 1) + months;
    final year = total ~/ 12;
    final month = total % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, date.day < lastDay ? date.day : lastDay);
  }

  /// Whole days from [from] to [to]; negative when [to] is earlier.
  static int daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day)
          .difference(DateTime.utc(from.year, from.month, from.day))
          .inDays;

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isWeekend(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  /// Every day from [start] to [end], both inclusive.
  static List<DateTime> range(DateTime start, DateTime end) {
    final count = daysBetween(start, end) + 1;
    if (count <= 0) return const [];
    return List.generate(count, (i) => addDays(dateOnly(start), i));
  }

  static DateTime? tryParseApi(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    return parsed == null ? null : dateOnly(parsed);
  }

  static DateTime parseApi(String value) => dateOnly(DateTime.parse(value));

  static String formatApi(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
