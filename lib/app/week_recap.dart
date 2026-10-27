/// Last week in numbers, for the card on Home. The rules work out every
/// figure; on iPhones with Apple Intelligence the coach writes them up
/// (OnDeviceCoach.describeWeek), otherwise [WeekRecap.summary] is shown.
library;

import 'budget_math.dart';
import 'format.dart';
import 'models.dart';

class WeekRecap {
  const WeekRecap({
    required this.start,
    required this.end,
    required this.days,
    required this.spent,
    required this.budget,
    required this.daysUnder,
    required this.noSpendDays,
    this.topCategory,
    this.biggest,
    this.weekBefore,
  });

  /// Sunday and Saturday.
  final DateTime start;
  final DateTime end;

  /// Days of the week inside the budget (all 7 unless it started midweek).
  final int days;

  /// Everyday spending (bills paid from money set aside aren't included).
  final double spent;

  /// The daily budgets of those days added up.
  final double budget;
  final int daysUnder;
  final int noSpendDays;
  final ({String name, double spent})? topCategory;
  final ({String what, double amount})? biggest;

  /// What was spent the week before, when that was a full week too.
  final double? weekBefore;

  double get leftOver => budget - spent;

  /// "12% less", "8% more", or null when it barely moved.
  String? get change {
    final before = weekBefore;
    if (before == null || before < 1) return null;
    final pct = ((spent - before) / before * 100).round();
    if (pct.abs() < 5) return null;
    return pct < 0 ? '${-pct}% less' : '$pct% more';
  }

  /// `Oct 18 – 24`
  String get label => start.month == end.month
      ? '${shortDate(start)} – ${end.day}'
      : '${shortDate(start)} – ${shortDate(end)}';

  /// The recap in plain words, from the rules.
  String get summary {
    final buf = StringBuffer();
    if (leftOver >= -0.005) {
      buf.write(
        'You spent ${money(spent)} of your ${money(budget)} budget last '
        'week and stayed under on $daysUnder of $days days.',
      );
    } else {
      buf.write(
        'You spent ${money(spent)} last week, ${money(-leftOver)} over your '
        '${money(budget)} budget, and stayed under on $daysUnder of $days '
        'days.',
      );
    }
    if (topCategory case final c?) {
      buf.write(' ${c.name} was your biggest category at ${money(c.spent)}.');
    }
    if (change case final c?) buf.write(' That\'s $c than the week before.');
    if (noSpendDays >= 2) {
      buf.write(' You had $noSpendDays no-spend days, nice.');
    }
    return buf.toString();
  }

  /// The same figures as JSON, rounded to cents, for the model.
  Map<String, Object> toFacts() => {
    'week': label,
    'daysCounted': days,
    'spent': _cents(spent),
    'budget': _cents(budget),
    if (leftOver >= -0.005)
      'underBudgetBy': _cents(leftOver)
    else
      'overBudgetBy': _cents(-leftOver),
    'daysUnderBudget': daysUnder,
    'noSpendDays': noSpendDays,
    if (topCategory case final c?)
      'biggestCategory': {'name': c.name, 'spent': _cents(c.spent)},
    if (biggest case final b?)
      'biggestExpense': {'what': b.what, 'amount': _cents(b.amount)},
    if (weekBefore case final w?) 'spentTheWeekBefore': _cents(w),
    'comparedWithTheWeekBefore': ?change,
  };
}

/// The Sunday-to-Saturday week before the one [today] is in, or null when
/// fewer than 3 of its days were inside the budget. [ledger] is
/// [dailyLedger] up to today.
WeekRecap? lastWeekRecap({
  required List<DayLedger> ledger,
  required List<Expense> expenses,
  required DateTime today,
}) {
  final t = dateOnly(today);
  final thisSunday = DateTime(t.year, t.month, t.day - t.weekday % 7);
  final start = DateTime(thisSunday.year, thisSunday.month, thisSunday.day - 7);
  final end = DateTime(start.year, start.month, start.day + 6);
  List<DayLedger> daysOf(DateTime from) {
    final to = DateTime(from.year, from.month, from.day + 6);
    return [
      for (final d in ledger)
        if (!d.day.isBefore(from) && !d.day.isAfter(to)) d,
    ];
  }

  final days = daysOf(start);
  if (days.length < 3) return null;
  final before = daysOf(DateTime(start.year, start.month, start.day - 7));

  final week = [
    for (final e in expenses)
      if (!e.planned &&
          !dateOnly(e.date).isBefore(start) &&
          !dateOnly(e.date).isAfter(end))
        e,
  ];
  final byCategory = <String, double>{};
  for (final e in week) {
    final name = e.filedUnder.label;
    byCategory[name] = (byCategory[name] ?? 0) + e.amount;
  }
  final top = byCategory.entries.fold<MapEntry<String, double>?>(
    null,
    (best, c) => best == null || c.value > best.value ? c : best,
  );
  final biggest = week.fold<Expense?>(
    null,
    (best, e) => best == null || e.amount > best.amount ? e : best,
  );
  return WeekRecap(
    start: start,
    end: end,
    days: days.length,
    spent: days.fold(0.0, (s, d) => s + d.spent),
    budget: days.fold(0.0, (s, d) => s + d.allowance),
    daysUnder: days.where((d) => !d.over).length,
    noSpendDays: days.where((d) => d.spent == 0).length,
    topCategory: top == null ? null : (name: top.key, spent: top.value),
    biggest: biggest == null
        ? null
        : (what: biggest.title, amount: biggest.amount),
    weekBefore: before.length == 7
        ? before.fold<double>(0, (s, d) => s + d.spent)
        : null,
  );
}

double _cents(double v) => (v * 100).round() / 100;
