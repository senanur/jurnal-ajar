const List<String> dayLabelsShort = ['min', 'sen', 'sel', 'rab', 'kam', 'jum', 'sab'];

const List<String> monthNamesId = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// Postgrest sometimes serializes bigint columns as JSON strings to avoid
/// precision loss, so callers can't assume `id`-like fields decode as [int].
int? asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Sunday that starts the week containing [date]. DateTime.weekday runs
/// Mon=1..Sun=7, so Sunday needs `% 7` to land on 0 instead of 7.
DateTime startOfWeek(DateTime date) {
  final daysFromSunday = date.weekday % 7;
  return dateOnly(date).subtract(Duration(days: daysFromSunday));
}

List<DateTime> weekDaysFor(DateTime date) {
  final start = startOfWeek(date);
  return List.generate(7, (i) => start.add(Duration(days: i)));
}

String formatDateIso(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Month/year label for a week strip, taken from the week's Thursday (index
/// 4) so a week straddling two months resolves the same way ISO week
/// numbering does.
String monthYearLabel(List<DateTime> weekDays) {
  final anchor = weekDays[4];
  return '${monthNamesId[anchor.month - 1]} ${anchor.year}';
}
