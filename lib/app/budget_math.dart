/// Pure budgeting maths. No Flutter, no clock — everything takes `today`
/// explicitly so it is trivially testable.
library;

import 'dart:math' as math;

import 'format.dart';
import 'models.dart';

class RunwaySnapshot {
  const RunwaySnapshot({
    required this.today,
    required this.termStart,
    required this.termEnd,
    required this.balance,
    required this.received,
    required this.reserved,
    this.savingsGoal = 0,
    required this.spentToday,
    required this.totalSpent,
    required this.everydaySpent,
    required this.daysLeft,
    required this.daysElapsed,
  });

  final DateTime today;
  final DateTime termStart;
  final DateTime termEnd;

  /// Starting balance plus money received so far, minus everything spent.
  final double balance;

  /// Money that has come in this term so far (paychecks, one-off payments).
  final double received;

  /// Sum of upcoming costs that haven't been paid yet, including overdue
  /// ones: that money is still owed.
  final double reserved;

  /// This term's savings goal, set aside like [reserved].
  final double savingsGoal;

  /// Everyday spending today (excludes paid upcoming costs).
  final double spentToday;

  /// Everything spent this term, including paid upcoming costs.
  final double totalSpent;

  /// Day-to-day spending this term: [totalSpent] minus paid upcoming costs,
  /// which were planned for and would otherwise distort the burn rate.
  final double everydaySpent;

  /// Days left in term, counting today.
  final int daysLeft;

  /// Days elapsed in term, counting today.
  final int daysElapsed;

  /// available = balance − reserved upcoming costs − savings goal
  double get available => balance - reserved - savingsGoal;

  /// How much of the savings goal is still there. Big costs are covered
  /// first, so overspending eats into savings before them.
  double get savingsKept =>
      (balance - reserved).clamp(0, math.max(0, savingsGoal)).toDouble();

  /// Spent out of the savings goal so far.
  double get dippedIntoSavings => savingsGoal - savingsKept;

  /// The most the savings goal can be right now: everything not already
  /// promised to a big cost.
  double get maxSavingsGoal => math.max(0, balance - reserved);

  /// daily allowance = (available + spentToday) / daysLeftInTerm
  double get dailyAllowance => (available + spentToday) / daysLeft;

  /// safe to spend today = daily allowance − spentToday
  double get safeToSpendToday => dailyAllowance - spentToday;

  /// Fraction of today's allowance already used (can exceed 1).
  double get usedToday =>
      dailyAllowance <= 0 ? 1 : (spentToday / dailyAllowance).clamp(0, 2);

  /// Average everyday spend per day so far.
  double get burnRate => everydaySpent / daysElapsed;

  /// How many more days the available money lasts at the current burn rate.
  /// `null` means "forever" (nothing spent yet).
  double? get runwayDays {
    if (burnRate <= 0) return null;
    return math.max(0, available) / burnRate;
  }

  /// today + available / burnRate
  DateTime? get runwayDate {
    final days = runwayDays;
    if (days == null) return null;
    return DateTime(today.year, today.month, today.day + days.floor());
  }

  /// Days between the money running out and the term ending (0 if covered).
  int get daysShort {
    final date = runwayDate;
    if (date == null) return 0;
    return math.max(0, daysBetween(date, termEnd));
  }

  bool get covered => daysShort == 0;

  int get termLength => math.max(1, daysBetween(termStart, termEnd));

  /// 0..1 position of a date along the term.
  double termProgress(DateTime d) =>
      (daysBetween(termStart, d) / termLength).clamp(0.0, 1.0);
}

/// [upcoming] holds only unpaid costs; each stays reserved until it's paid.
/// [incomes] count only for the paydays that have already arrived.
RunwaySnapshot computeRunway({
  required Term term,
  required List<Expense> expenses,
  required List<UpcomingCost> upcoming,
  List<Income> incomes = const [],
  required DateTime today,
}) {
  final day = dateOnly(today);
  var total = 0.0;
  var everyday = 0.0;
  var todaySpend = 0.0;
  for (final e in expenses) {
    total += e.amount;
    if (e.planned) continue;
    everyday += e.amount;
    if (sameDay(e.date, day)) todaySpend += e.amount;
  }
  var reserved = 0.0;
  for (final c in upcoming) {
    reserved += c.amount;
  }
  final received = incomeReceived(incomes, term: term, today: day);
  return RunwaySnapshot(
    today: day,
    termStart: dateOnly(term.start),
    termEnd: dateOnly(term.end),
    balance: term.startingBalance + received - total,
    received: received,
    reserved: reserved,
    savingsGoal: term.savingsGoal,
    spentToday: todaySpend,
    totalSpent: total,
    everydaySpent: everyday,
    daysLeft: math.max(1, daysBetween(day, term.end) + 1),
    daysElapsed: math.max(1, daysBetween(term.start, day) + 1),
  );
}

/// Every payday of [income] from [from] to [to], inclusive, in order.
/// Monthly pay on the 31st lands on the last day of shorter months.
Iterable<DateTime> paydays(
  Income income, {
  required DateTime from,
  required DateTime to,
}) sync* {
  final first = dateOnly(income.firstDate);
  final endsOn = income.endsOn;
  final last = endsOn == null || endsOn.isAfter(to)
      ? dateOnly(to)
      : dateOnly(endsOn);
  final start = dateOnly(from);
  for (var n = 0; ; n++) {
    final DateTime date;
    switch (income.frequency) {
      case IncomeFrequency.once:
        if (n > 0) return;
        date = first;
      case IncomeFrequency.weekly:
        date = DateTime(first.year, first.month, first.day + 7 * n);
      case IncomeFrequency.biweekly:
        date = DateTime(first.year, first.month, first.day + 14 * n);
      case IncomeFrequency.monthly:
        date = _monthsAfter(first, n);
    }
    if (date.isAfter(last)) return;
    if (!date.isBefore(start)) yield date;
  }
}

/// [first] moved on [n] months, keeping its day of the month where it can:
/// the 31st lands on the last day of shorter months.
DateTime _monthsAfter(DateTime first, int n) {
  final lastDay = DateTime(first.year, first.month + n + 1, 0).day;
  return DateTime(first.year, first.month + n, math.min(first.day, lastDay));
}

/// Each month's [bill] due from [from] to [to], inclusive, ready to reserve.
/// Ids are one per bill per month, so the same month is never added twice.
List<UpcomingCost> billsDue(
  RepeatingBill bill, {
  required DateTime from,
  required DateTime to,
}) {
  final first = dateOnly(bill.firstDue);
  final start = dateOnly(from);
  final due = <UpcomingCost>[];
  for (var n = 0; ; n++) {
    final date = _monthsAfter(first, n);
    if (date.isAfter(to)) return due;
    if (date.isBefore(start)) continue;
    due.add(
      UpcomingCost(
        id: '${bill.id}@${date.year}-${date.month}',
        emoji: bill.emoji,
        name: bill.name,
        amount: bill.amount,
        dueDate: date,
        billId: bill.id,
      ),
    );
  }
}

/// Money that has arrived this term, up to and including [today]. Option A
/// from the README: income never counts before it lands.
double incomeReceived(
  List<Income> incomes, {
  required Term term,
  required DateTime today,
}) {
  final until = today.isAfter(term.end) ? term.end : today;
  var total = 0.0;
  for (final i in incomes) {
    total += i.amount * paydays(i, from: term.start, to: until).length;
  }
  return total;
}

/// The first payday of [income] after [day], term or not; null once it has
/// stopped or a one-off payment has arrived.
DateTime? paydayAfter(Income income, DateTime day) => paydays(
  income,
  from: DateTime(day.year, day.month, day.day + 1),
  to: DateTime(day.year + 1, day.month, day.day + 1),
).firstOrNull;

/// The next payment after [today] and before the term ends, if any.
({Income income, DateTime date})? nextIncome(
  List<Income> incomes, {
  required Term term,
  required DateTime today,
}) {
  final from = DateTime(today.year, today.month, today.day + 1);
  ({Income income, DateTime date})? next;
  for (final i in incomes) {
    final date = paydays(i, from: from, to: term.end).firstOrNull;
    if (date != null && (next == null || date.isBefore(next.date))) {
      next = (income: i, date: date);
    }
  }
  return next;
}

/// Repeating pay that is still coming after [after] (not stopped by then).
List<Income> continuingIncomes(List<Income> incomes, DateTime after) => [
  for (final i in incomes)
    if (i.repeats && (i.endsOn == null || i.endsOn!.isAfter(after))) i,
];

/// Once a monthly budget's month is over: the month [today] falls in, how
/// much was overspent if the money ran out, and how much of the savings
/// goal was kept ([saved]; it leaves the budget). Leftover money carries
/// over, and so does the goal; pay that keeps coming counts in any months
/// skipped in between (the app wasn't opened). [upcoming] are the unpaid
/// costs, still owed. Null for a semester, or while the month is running.
({Term term, double overspent, double saved})? nextMonth({
  required Term term,
  required List<Expense> expenses,
  required List<Income> incomes,
  List<UpcomingCost> upcoming = const [],
  required DateTime today,
}) {
  final day = dateOnly(today);
  if (term.period != BudgetPeriod.monthly || !day.isAfter(term.end)) {
    return null;
  }
  // Whole cents: summing amounts like 0.10 + 0.20 leaves float dust that
  // would otherwise show up as a $0.00 overspend.
  double cents(double v) => (v * 100).round() / 100;
  final end = computeRunway(
    term: term,
    expenses: expenses,
    upcoming: upcoming,
    incomes: incomes,
    today: term.end,
  );
  final saved = cents(end.savingsKept);
  var left = cents(end.balance - saved);
  final continuing = continuingIncomes(incomes, term.end);
  var start = DateTime(term.end.year, term.end.month, term.end.day + 1);
  while (true) {
    final month = Term(
      name: monthName(start),
      start: start,
      end: endOfMonth(start),
      startingBalance: math.max(0, left),
      period: BudgetPeriod.monthly,
      savingsGoal: term.savingsGoal,
    );
    if (!day.isAfter(month.end)) {
      return (term: month, overspent: math.max(0, -left), saved: saved);
    }
    left = cents(
      left + incomeReceived(continuing, term: month, today: month.end),
    );
    start = DateTime(month.end.year, month.end.month, month.end.day + 1);
  }
}

/// The totals for one finished term or month.
class TermSummary {
  const TermSummary({
    required this.startedWith,
    required this.moneyIn,
    required this.spent,
    required this.needSpent,
    required this.topCategories,
    this.savingsGoal = 0,
    this.saved = 0,
  });

  final double startedWith;

  /// Pay and one-off money that arrived while it ran.
  final double moneyIn;
  final double spent;

  /// The part of [spent] marked as a need.
  final double needSpent;

  /// 0..1; half and half when nothing was spent.
  double get needShare => spent == 0 ? 0.5 : needSpent / spent;

  /// Biggest spending categories first, at most three.
  final List<({CategoryRef category, double amount})> topCategories;

  final double savingsGoal;

  /// How much of [savingsGoal] was kept.
  final double saved;

  /// Negative when more was spent than there was. Includes [saved].
  double get left => startedWith + moneyIn - spent;

  /// What was left besides the savings: it carries on as spending money.
  double get leftOver => left - saved;
}

/// The last day [past] ran: its end, or earlier if it was ended early.
DateTime _lastDay(PastTerm past) {
  final ended = dateOnly(past.endedOn);
  return ended.isBefore(past.term.end) ? ended : past.term.end;
}

Map<CategoryRef, double> _byCategory(List<Expense> expenses) {
  final totals = <CategoryRef, double>{};
  for (final e in expenses) {
    final key = e.filedUnder;
    totals[key] = (totals[key] ?? 0) + e.amount;
  }
  return totals;
}

TermSummary summarize(PastTerm past) {
  final term = past.term;
  final byCategory = _byCategory(past.expenses);
  var spent = 0.0;
  var need = 0.0;
  for (final e in past.expenses) {
    spent += e.amount;
    if (e.isNeed) need += e.amount;
  }
  final top = [
    for (final MapEntry(:key, :value) in byCategory.entries)
      (category: key, amount: value),
  ]..sort((a, b) => b.amount.compareTo(a.amount));
  return TermSummary(
    startedWith: term.startingBalance,
    moneyIn: incomeReceived(past.incomes, term: term, today: _lastDay(past)),
    spent: spent,
    needSpent: need,
    topCategories: top.take(3).toList(),
    savingsGoal: term.savingsGoal,
    saved: past.saved,
  );
}

/// How much one category's spending per day moved from the term before.
/// Per day, so a 30-day month compares fairly with a 31-day one.
class CategoryChange {
  const CategoryChange(
    this.category, {
    required this.perDayNow,
    required this.perDayBefore,
  });

  final CategoryRef category;
  final double perDayNow;
  final double perDayBefore;

  /// −0.3 is 30% less, 0.25 is 25% more.
  double get change => perDayNow / perDayBefore - 1;
}

/// The category whose spending fell the most since [before], or if none
/// fell, the one that rose the most. Only moves of 10% or more count, in
/// categories with at least $10 spent before, so small change isn't news.
CategoryChange? biggestChange(PastTerm now, PastTerm before) {
  int days(PastTerm p) =>
      math.max(1, daysBetween(p.term.start, _lastDay(p)) + 1);
  final nowDays = days(now);
  final beforeDays = days(before);
  final nowTotals = _byCategory(now.expenses);
  final changes = [
    for (final MapEntry(key: category, value: total) in _byCategory(
      before.expenses,
    ).entries)
      if (total >= 10)
        CategoryChange(
          category,
          perDayNow: (nowTotals[category] ?? 0) / nowDays,
          perDayBefore: total / beforeDays,
        ),
  ]..sort((a, b) => a.change.compareTo(b.change));
  if (changes.isEmpty) return null;
  if (changes.first.change <= -0.1) return changes.first;
  if (changes.last.change >= 0.1) return changes.last;
  return null;
}

/// How many terms or months in a row, newest first, hit their savings goal.
int savingsStreak(List<SavedTerm> history) {
  var n = 0;
  for (final t in history) {
    if (!t.hitGoal) break;
    n++;
  }
  return n;
}

/// Consecutive days with at least one logged expense. Today not being logged
/// yet doesn't break the streak — it only counts once you log.
int computeStreak(List<Expense> expenses, DateTime today) {
  final logged = {for (final e in expenses) dateOnly(e.date)};
  var cursor = dateOnly(today);
  if (!logged.contains(cursor)) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  var streak = 0;
  while (logged.contains(cursor)) {
    streak++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return streak;
}

enum PetMood {
  thriving('Thriving', '✨'),
  chill('Chill', '😌'),
  worried('Worried', '😰');

  const PetMood(this.label, this.emoji);
  final String label;
  final String emoji;
}

PetMood moodFor(RunwaySnapshot s) {
  if (s.safeToSpendToday < 0 || s.daysShort > 21) return PetMood.worried;
  if (s.covered) return PetMood.thriving;
  return PetMood.chill;
}

/// Pet progression derived from the streak.
class PetLevel {
  const PetLevel(this.level, this.xp, this.xpForNext);
  final int level;
  final int xp;
  final int xpForNext;
  double get progress => xp / xpForNext;

  static const xpPerDay = 25;
  static const xpPerLevel = 100;

  factory PetLevel.fromStreak(int streak) {
    final total = streak * xpPerDay;
    return PetLevel(1 + total ~/ xpPerLevel, total % xpPerLevel, xpPerLevel);
  }
}

class NeedWantSplit {
  const NeedWantSplit(this.need, this.want);
  final double need;
  final double want;
  double get total => need + want;
  double get needShare => total == 0 ? 0.5 : need / total;
}

/// Need vs want over the last 7 days (including today).
NeedWantSplit weekSplit(List<Expense> expenses, DateTime today) {
  var need = 0.0, want = 0.0;
  for (final e in expenses) {
    final age = daysBetween(e.date, today);
    if (age < 0 || age > 6) continue;
    if (e.isNeed) {
      need += e.amount;
    } else {
      want += e.amount;
    }
  }
  return NeedWantSplit(need, want);
}

/// Splits [total] evenly between you and [others] people. Everyone else's
/// share is rounded to cents; you absorb the leftover cent(s).
({double mine, double each}) splitEvenly(double total, int others) {
  if (others <= 0) return (mine: total, each: 0);
  final each = (total / (others + 1) * 100).round() / 100;
  final mine = ((total - each * others) * 100).round() / 100;
  return (mine: mine, each: each);
}
