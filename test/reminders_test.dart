import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/models.dart';
import 'package:runway/app/reminders.dart';

void main() {
  // Tuesday Oct 27, 3pm.
  final now = DateTime(2026, 10, 27, 15);
  final term = Term(
    name: 'Fall',
    start: DateTime(2026, 9, 1),
    end: DateTime(2026, 12, 15),
    startingBalance: 2000,
  );
  UpcomingCost cost(String name, double amount, DateTime due) => UpcomingCost(
    id: name,
    emoji: '',
    name: name,
    amount: amount,
    dueDate: due,
  );
  Expense spentToday() => Expense(
    id: 'coffee',
    amount: 4.5,
    category: ExpenseCategory.coffee,
    isNeed: false,
    date: DateTime(2026, 10, 27, 9),
  );

  List<PlannedReminder> plan(
    ReminderSettings settings, {
    List<UpcomingCost> upcoming = const [],
    List<Expense> expenses = const [],
    bool hideAmounts = false,
    DateTime? at,
    Term? within,
  }) => planReminders(
    settings: settings,
    now: at ?? now,
    term: within ?? term,
    upcoming: upcoming,
    expenses: expenses,
    hideAmounts: hideAmounts,
  );

  test('nothing when every reminder is off', () {
    expect(plan(const ReminderSettings()), isEmpty);
  });

  group('bills', () {
    test('9am the day before, with the name and amount', () {
      final r = plan(
        const ReminderSettings(bills: true),
        upcoming: [cost('Rent', 850, DateTime(2026, 10, 30))],
      ).single;
      expect(r.at, DateTime(2026, 10, 29, 9));
      expect(r.title, 'Due tomorrow');
      expect(
        r.body,
        'Rent (\$850.00) is due tomorrow. It\'s already set aside.',
      );
      expect(r.tap, ReminderTap.home);
    });

    test('two due together are one reminder with the total', () {
      final r = plan(
        const ReminderSettings(bills: true),
        upcoming: [
          cost('Rent', 850, DateTime(2026, 10, 30)),
          cost('Phone', 40, DateTime(2026, 10, 30, 12)),
        ],
      ).single;
      expect(
        r.body,
        'Rent and Phone (\$890.00 in all) are due tomorrow. They\'re already '
        'set aside.',
      );
    });

    test('with the app lock on, no names or amounts', () {
      final r = plan(
        const ReminderSettings(bills: true),
        upcoming: [cost('Rent', 850, DateTime(2026, 10, 30))],
        hideAmounts: true,
      ).single;
      expect(r.title, 'Bill reminder');
      expect(r.body, isNot(contains('Rent')));
      expect(r.body, isNot(contains('\$')));
    });

    test('not when 9am has already passed', () {
      // Due tomorrow, but it's 3pm today.
      expect(
        plan(
          const ReminderSettings(bills: true),
          upcoming: [cost('Rent', 850, DateTime(2026, 10, 28))],
        ),
        isEmpty,
      );
    });
  });

  group('evening check-in', () {
    test('8pm every day, skipping today once something is logged', () {
      final before = plan(const ReminderSettings(checkIn: true));
      expect(before.first.at, DateTime(2026, 10, 27, 20));
      expect(before.length, 14);
      expect(before.first.tap, ReminderTap.quickAdd);

      final after = plan(
        const ReminderSettings(checkIn: true),
        expenses: [spentToday()],
      );
      expect(after.first.at, DateTime(2026, 10, 28, 20));
      expect(after.length, 13);
    });

    test('stops when the budget ends', () {
      final ending = Term(
        name: 'Oct',
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 31),
        startingBalance: 500,
      );
      final r = plan(const ReminderSettings(checkIn: true), within: ending);
      expect(r.last.at, DateTime(2026, 10, 31, 20));
    });
  });

  group('weekly recap', () {
    test('Sunday at 9am', () {
      final r = plan(const ReminderSettings(weeklyRecap: true));
      expect(r.map((e) => e.at), [
        DateTime(2026, 11, 1, 9),
        DateTime(2026, 11, 8, 9),
      ]);
      expect(r.first.title, 'Your week\'s recap is ready');
    });

    test('not until a week has 3 days inside the budget', () {
      final fresh = Term(
        name: 'Nov',
        start: DateTime(2026, 10, 30), // a Friday
        end: DateTime(2026, 11, 30),
        startingBalance: 500,
      );
      // Week of Oct 25–31 has only Fri and Sat: no recap on Nov 1.
      final r = plan(const ReminderSettings(weeklyRecap: true), within: fresh);
      expect(r.map((e) => e.at), [DateTime(2026, 11, 8, 9)]);
    });
  });

  test('at most one a day: bill, then recap, then check-in', () {
    final r = plan(
      const ReminderSettings(bills: true, checkIn: true, weeklyRecap: true),
      // Due Monday: its reminder lands on Sunday, the recap's day.
      upcoming: [cost('Rent', 850, DateTime(2026, 11, 2))],
    );
    final sunday = r.where((e) => e.at.day == 1 && e.at.month == 11);
    expect(sunday.single.title, 'Due tomorrow');
    final days = r.map((e) => DateTime(e.at.year, e.at.month, e.at.day));
    expect(days.toSet().length, r.length);
    expect(
      r.firstWhere((e) => e.at == DateTime(2026, 11, 8, 9)).title,
      'Your week\'s recap is ready',
    );
  });

  test('settings round-trip through storage', () {
    const s = ReminderSettings(bills: true, weeklyRecap: true);
    final back = ReminderSettings.decode(s.encode());
    expect(back.bills, isTrue);
    expect(back.checkIn, isFalse);
    expect(back.weeklyRecap, isTrue);
    expect(ReminderSettings.decode(null).any, isFalse);
  });
}
