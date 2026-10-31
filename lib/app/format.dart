/// Tiny formatting helpers (no intl dependency needed for USD + short dates).
library;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// `October`
String monthName(DateTime d) => _monthNames[d.month - 1];

/// The last day of [d]'s calendar month.
DateTime endOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

/// `$1,234.56`. Drops cents when [cents] is false. Never shows `−$0.00`
/// for an amount that rounds to zero, and shows `—` for a value that isn't
/// a number (a bug upstream, but never `$NaN` on screen).
String money(double value, {bool cents = true}) {
  if (!value.isFinite) return '—';
  // Past 1e21 toStringAsFixed switches to exponents ("1e+21"); BigInt
  // keeps every digit. Cents mean nothing at that size.
  final fixed = value.abs() < 1e15
      ? value.abs().toStringAsFixed(cents ? 2 : 0)
      : '${BigInt.from(value.abs().roundToDouble())}${cents ? '.00' : ''}';
  final negative = value < 0 && fixed.contains(RegExp('[1-9]'));
  final parts = fixed.split('.');
  final whole = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  final decimals = parts.length > 1 ? '.${parts[1]}' : '';
  return '${negative ? '−' : ''}\$$buf$decimals';
}

/// `Nov 27`
String shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

/// `Oct 1 – Dec 11, 2026`, or with both years when it spans two.
String dateRange(DateTime start, DateTime end) => start.year == end.year
    ? '${shortDate(start)} – ${shortDate(end)}, ${end.year}'
    : '${shortDate(start)}, ${start.year} – ${shortDate(end)}, ${end.year}';

/// Strips the time component (local calendar day).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole calendar days from [a] to [b], immune to DST shifts.
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

/// `Today 9:14`, `Yesterday`, or `Sep 30`.
String relativeDay(DateTime d, DateTime today) {
  final diff = daysBetween(d, today);
  if (diff == 0) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return 'Today $h:$m${d.hour < 12 ? 'am' : 'pm'}';
  }
  if (diff == 1) return 'Yesterday';
  return shortDate(d);
}
