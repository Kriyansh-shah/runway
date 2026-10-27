/// Reminders scheduled on the phone itself: no server. A notification's
/// words are fixed when it's scheduled, so the plan is redone every time
/// the app opens or something changes ([planReminders]); that's also how
/// the evening check-in disappears once something is logged that day.
library;

import 'format.dart';
import 'models.dart';

/// What tapping a reminder opens.
enum ReminderTap { home, quickAdd }

class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.tap,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;
  final ReminderTap tap;

  @override
  String toString() => '$at $title: $body';
}

/// Shows [PlannedReminder]s on the phone. [NoReminders] where there's no
/// such thing (web, the macOS preview, tests).
abstract interface class ReminderScheduler {
  bool get supported;

  /// Asks to show notifications; true if allowed.
  Future<bool> requestPermission();

  /// Cancels everything scheduled before and schedules [reminders].
  Future<void> replaceAll(List<PlannedReminder> reminders);
}

class NoReminders implements ReminderScheduler {
  const NoReminders();

  @override
  bool get supported => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {}
}

/// The next [days] days of reminders, at most one a day: a bill due the
/// next day comes first, then Sunday's recap, then the evening check-in.
/// Nothing past the end of [term]. With [hideAmounts] (the app lock is on)
/// bills don't show names or amounts on the lock screen.
List<PlannedReminder> planReminders({
  required ReminderSettings settings,
  required DateTime now,
  required Term term,
  required List<UpcomingCost> upcoming,
  required List<Expense> expenses,
  bool hideAmounts = false,
  int days = 14,
}) {
  if (!settings.any) return const [];
  final today = dateOnly(now);
  final last = dateOnly(term.end);
  final loggedToday = expenses.any((e) => sameDay(e.date, today));
  final planned = <PlannedReminder>[];
  for (var i = 0; i < days; i++) {
    final day = DateTime(today.year, today.month, today.day + i);
    if (day.isAfter(last)) break;
    DateTime at(int hour) => DateTime(day.year, day.month, day.day, hour);
    final tomorrow = DateTime(day.year, day.month, day.day + 1);
    final due = settings.bills
        ? [
            for (final c in upcoming)
              if (sameDay(c.dueDate, tomorrow)) c,
          ]
        : const <UpcomingCost>[];

    final PlannedReminder? reminder;
    if (due.isNotEmpty && at(9).isAfter(now)) {
      reminder = _billReminder(i, at(9), due, hideAmounts: hideAmounts);
    } else if (settings.weeklyRecap &&
        day.weekday == DateTime.sunday &&
        at(9).isAfter(now) &&
        _recapReady(day, term)) {
      reminder = PlannedReminder(
        id: i * 10 + 2,
        at: at(9),
        title: 'Your week\'s recap is ready',
        body: 'See how last week went.',
        tap: ReminderTap.home,
      );
    } else if (settings.checkIn &&
        at(20).isAfter(now) &&
        !(i == 0 && loggedToday)) {
      reminder = PlannedReminder(
        id: i * 10 + 3,
        at: at(20),
        title: 'Anything to log today?',
        body: 'Nothing logged yet today. Tap to add it.',
        tap: ReminderTap.quickAdd,
      );
    } else {
      reminder = null;
    }
    if (reminder != null) planned.add(reminder);
  }
  return planned;
}

PlannedReminder _billReminder(
  int day,
  DateTime at,
  List<UpcomingCost> due, {
  required bool hideAmounts,
}) {
  final String body;
  if (hideAmounts) {
    body = due.length == 1
        ? 'A bill is due tomorrow. Open Runway to see it.'
        : '${due.length} bills are due tomorrow. Open Runway to see them.';
  } else if (due.length == 1) {
    final c = due.single;
    body =
        '${c.name} (${money(c.amount)}) is due tomorrow. It\'s already set '
        'aside.';
  } else {
    final names = [for (final c in due) c.name];
    final total = due.fold<double>(0, (s, c) => s + c.amount);
    body =
        '${names.take(names.length - 1).join(', ')} and ${names.last} '
        '(${money(total)} in all) are due tomorrow. They\'re already set '
        'aside.';
  }
  return PlannedReminder(
    id: day * 10 + 1,
    at: at,
    title: hideAmounts ? 'Bill reminder' : 'Due tomorrow',
    body: body,
    tap: ReminderTap.home,
  );
}

/// Whether Home has a recap for the week ending the day before [sunday]:
/// at least 3 of its days inside [term] (see lastWeekRecap).
bool _recapReady(DateTime sunday, Term term) {
  final weekStart = DateTime(sunday.year, sunday.month, sunday.day - 7);
  final weekEnd = DateTime(sunday.year, sunday.month, sunday.day - 1);
  final from = dateOnly(term.start).isAfter(weekStart)
      ? dateOnly(term.start)
      : weekStart;
  final to = dateOnly(term.end).isBefore(weekEnd)
      ? dateOnly(term.end)
      : weekEnd;
  return daysBetween(from, to) + 1 >= 3;
}
