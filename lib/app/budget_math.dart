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
    required this.reserved,
    required this.spentToday,
    required this.totalSpent,
    required this.daysLeft,
    required this.daysElapsed,
  });

  final DateTime today;
  final DateTime termStart;
  final DateTime termEnd;

  /// Starting balance minus everything spent so far.
  final double balance;

  /// Sum of upcoming costs that haven't come due yet.
  final double reserved;
  final double spentToday;
  final double totalSpent;

  /// Days left in term, counting today.
  final int daysLeft;

  /// Days elapsed in term, counting today.
  final int daysElapsed;

  /// available = balance − reserved upcoming costs
  double get available => balance - reserved;

  /// daily allowance = (available + spentToday) / daysLeftInTerm
  double get dailyAllowance => (available + spentToday) / daysLeft;

  /// safe to spend today = daily allowance − spentToday
  double get safeToSpendToday => dailyAllowance - spentToday;

  /// Fraction of today's allowance already used (can exceed 1).
  double get usedToday =>
      dailyAllowance <= 0 ? 1 : (spentToday / dailyAllowance).clamp(0, 2);

  /// Average spend per day so far.
  double get burnRate => totalSpent / daysElapsed;

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

RunwaySnapshot computeRunway({
  required Term term,
  required List<Expense> expenses,
  required List<UpcomingCost> upcoming,
  required DateTime today,
}) {
  final day = dateOnly(today);
  var total = 0.0;
  var todaySpend = 0.0;
  for (final e in expenses) {
    total += e.amount;
    if (sameDay(e.date, day)) todaySpend += e.amount;
  }
  var reserved = 0.0;
  for (final c in upcoming) {
    if (!c.dueDate.isBefore(day)) reserved += c.amount;
  }
  return RunwaySnapshot(
    today: day,
    termStart: dateOnly(term.start),
    termEnd: dateOnly(term.end),
    balance: term.startingBalance - total,
    reserved: reserved,
    spentToday: todaySpend,
    totalSpent: total,
    daysLeft: math.max(1, daysBetween(day, term.end) + 1),
    daysElapsed: math.max(1, daysBetween(term.start, day) + 1),
  );
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
