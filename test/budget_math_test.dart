import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/budget_math.dart';
import 'package:runway/app/models.dart';
import 'package:runway/app/repository.dart';

void main() {
  final today = DateTime(2026, 10, 2);
  DateTime day(int offset) => DateTime(2026, 10, 2 + offset);

  Expense spend(
    double amount,
    int dayOffset, {
    bool need = false,
    ExpenseCategory c = ExpenseCategory.other,
  }) => Expense(
    id: '$amount@$dayOffset',
    amount: amount,
    category: c,
    isNeed: need,
    date: day(dayOffset).add(const Duration(hours: 12)),
  );

  final term = Term(
    name: 'T',
    start: day(-9),
    end: day(9),
    startingBalance: 1000,
  );

  group('computeRunway', () {
    test('implements the spec formulas', () {
      final s = computeRunway(
        term: term,
        expenses: [spend(100, -5), spend(80, -1), spend(20, 0)],
        upcoming: [
          UpcomingCost(
            id: 'a',
            emoji: '✈️',
            name: 'Flight',
            amount: 300,
            dueDate: day(5),
          ),
          // Overdue but unpaid: still owed, so still reserved.
          UpcomingCost(
            id: 'b',
            emoji: '📱',
            name: 'Old bill',
            amount: 50,
            dueDate: day(-2),
          ),
        ],
        today: today,
      );

      expect(s.balance, 800); // 1000 − 200
      expect(s.reserved, 350);
      expect(s.available, 450); // balance − reserved
      expect(s.spentToday, 20);
      expect(s.daysLeft, 10); // today .. day(9) inclusive
      expect(s.daysElapsed, 10); // day(-9) .. today inclusive
      expect(s.dailyAllowance, closeTo((450 + 20) / 10, 1e-9));
      expect(s.safeToSpendToday, closeTo(47 - 20, 1e-9));
      expect(s.burnRate, closeTo(200 / 10, 1e-9));
      // runway = today + 450 / 20 = 22.5 days → covered past term end.
      expect(s.runwayDate, day(22));
      expect(s.daysShort, 0);
      expect(s.covered, isTrue);
    });

    test('reports days short when money runs out before term ends', () {
      final s = computeRunway(
        term: Term(
          name: 'T',
          start: day(-9),
          end: day(30),
          startingBalance: 1000,
        ),
        expenses: [spend(500, -3)],
        upcoming: const [],
        today: today,
      );
      // available 500, burn 50/day → 10 days → runs out day(10); ends day(30).
      expect(s.burnRate, 50);
      expect(s.runwayDate, day(10));
      expect(s.daysShort, 20);
      expect(s.covered, isFalse);
    });

    test('no spending yet means runway is unlimited', () {
      final s = computeRunway(
        term: term,
        expenses: const [],
        upcoming: const [],
        today: today,
      );
      expect(s.burnRate, 0);
      expect(s.runwayDate, isNull);
      expect(s.covered, isTrue);
      expect(s.safeToSpendToday, closeTo(1000 / 10, 1e-9));
    });

    test('overspending today drives safe-to-spend negative', () {
      final s = computeRunway(
        term: term,
        expenses: [spend(120, 0)],
        upcoming: const [],
        today: today,
      );
      expect(s.dailyAllowance, closeTo(100, 1e-9)); // (880 + 120) / 10
      expect(s.safeToSpendToday, closeTo(-20, 1e-9));
      expect(moodFor(s), PetMood.worried);
    });

    test('last day of term still divides by one day', () {
      final s = computeRunway(
        term: Term(name: 'T', start: day(-9), end: today, startingBalance: 100),
        expenses: const [],
        upcoming: const [],
        today: today,
      );
      expect(s.daysLeft, 1);
      expect(s.dailyAllowance, 100);
    });
  });

  group('streak', () {
    test('counts consecutive logged days ending today', () {
      expect(
        computeStreak([
          spend(1, 0),
          spend(1, -1),
          spend(1, -2),
          spend(1, -4),
        ], today),
        3,
      );
    });

    test('an unlogged today does not break the streak yet', () {
      expect(computeStreak([spend(1, -1), spend(1, -2)], today), 2);
    });

    test('a missed yesterday resets it', () {
      expect(computeStreak([spend(1, -2), spend(1, -3)], today), 0);
    });

    test('pet levels up every 4 streak days', () {
      final l = PetLevel.fromStreak(13);
      expect(l.level, 4);
      expect(l.xp, 25);
      expect(l.progress, 0.25);
    });
  });

  test('week split only counts the last 7 days', () {
    final split = weekSplit([
      spend(10, 0, need: true),
      spend(5, -6),
      spend(99, -7, need: true),
    ], today);
    expect(split.need, 10);
    expect(split.want, 5);
  });

  test('mock data lands at 14 days short with a 13-day streak', () {
    final data = MockBudgetRepository.seed(today);
    final s = computeRunway(
      term: data.term,
      expenses: data.expenses,
      upcoming: data.upcoming,
      today: today,
    );
    expect(s.totalSpent, closeTo(MockBudgetRepository.seededTotal + 4.5, 1e-6));
    expect(s.daysLeft, 71);
    expect(s.daysShort, 14);
    expect(computeStreak(data.expenses, today), 13);
  });

  group('splitEvenly', () {
    test('divides evenly between you and roommates', () {
      expect(splitEvenly(42, 2), (mine: 14.0, each: 14.0));
    });

    test('you absorb the leftover cent', () {
      final s = splitEvenly(10, 2); // 3.33 each for them
      expect(s.each, 3.33);
      expect(s.mine, 3.34);
      expect(s.mine + s.each * 2, closeTo(10, 1e-9));
    });

    test('nobody to split with means you pay it all', () {
      expect(splitEvenly(25, 0), (mine: 25.0, each: 0.0));
    });
  });

  group('income (counts only once it arrives)', () {
    Income pay(
      IncomeFrequency f,
      DateTime first, {
      double amount = 100,
      DateTime? endsOn,
    }) => Income(
      id: '$f',
      name: 'Job',
      amount: amount,
      frequency: f,
      firstDate: first,
      endsOn: endsOn,
    );

    test('weekly and biweekly paydays step by calendar days', () {
      expect(
        paydays(
          pay(IncomeFrequency.weekly, day(-9)),
          from: day(-9),
          to: day(9),
        ),
        [day(-9), day(-2), day(5)],
      );
      expect(
        paydays(
          pay(IncomeFrequency.biweekly, day(-9)),
          from: day(-9),
          to: day(9),
        ),
        [day(-9), day(5)],
      );
    });

    test('monthly pay on the 31st falls back to short months', () {
      final dates = paydays(
        pay(IncomeFrequency.monthly, DateTime(2027, 1, 31)),
        from: DateTime(2027, 1, 1),
        to: DateTime(2027, 4, 30),
      );
      expect(dates, [
        DateTime(2027, 1, 31),
        DateTime(2027, 2, 28),
        DateTime(2027, 3, 31),
        DateTime(2027, 4, 30),
      ]);
    });

    test('a one-time payment happens once; stopped pay ends', () {
      expect(
        paydays(pay(IncomeFrequency.once, day(1)), from: day(-9), to: day(9)),
        [day(1)],
      );
      expect(
        paydays(
          pay(IncomeFrequency.weekly, day(-9), endsOn: day(0)),
          from: day(-9),
          to: day(9),
        ),
        [day(-9), day(-2)],
      );
    });

    test('only paydays up to today count, and only inside the term', () {
      final incomes = [
        // -16 is before the term; -9 and -2 have arrived; 5 hasn't yet.
        pay(IncomeFrequency.weekly, day(-16)),
        pay(IncomeFrequency.once, day(3), amount: 500), // not here yet
      ];
      expect(incomeReceived(incomes, term: term, today: today), 200);
      // Long after the term: everything inside it, nothing past day(9).
      expect(incomeReceived(incomes, term: term, today: day(30)), 800);
    });

    test('received money raises the balance, future money does not', () {
      final s = computeRunway(
        term: term,
        expenses: [spend(200, -1)],
        upcoming: const [],
        incomes: [
          pay(IncomeFrequency.once, day(-3), amount: 150),
          pay(IncomeFrequency.once, day(2), amount: 999),
        ],
        today: today,
      );
      expect(s.received, 150);
      expect(s.balance, 950); // 1000 + 150 − 200
      expect(s.dailyAllowance, closeTo(950 / 10, 1e-9));
    });

    test('next payment is the soonest one after today', () {
      final weekly = pay(IncomeFrequency.weekly, day(-9));
      final gift = pay(IncomeFrequency.once, day(3), amount: 50);
      final next = nextIncome([weekly, gift], term: term, today: today);
      expect(next?.income, gift);
      expect(next?.date, day(3));
      expect(nextIncome([weekly], term: term, today: day(6)), isNull);
    });
  });

  test('a paid upcoming cost leaves the balance but not daily spending', () {
    final planned = Expense(
      id: 'flight',
      amount: 300,
      category: ExpenseCategory.bills,
      isNeed: true,
      date: today.add(const Duration(hours: 10)),
      planned: true,
    );
    final s = computeRunway(
      term: term,
      expenses: [spend(100, -1), spend(20, 0), planned],
      upcoming: const [],
      today: today,
    );
    expect(s.balance, 580); // 1000 − 100 − 20 − 300
    expect(s.totalSpent, 420);
    expect(s.spentToday, 20);
    expect(s.burnRate, closeTo(120 / 10, 1e-9));
  });
}
