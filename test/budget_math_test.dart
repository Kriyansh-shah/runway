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

  group('savings jars', () {
    JarDeposit deposit(double amount, int dayOffset) => JarDeposit(
      id: 'd$amount@$dayOffset',
      jarId: 'jar',
      amount: amount,
      date: day(dayOffset).add(const Duration(hours: 9)),
    );

    test('money put in this term is no longer spending money', () {
      final before = computeRunway(
        term: term,
        expenses: [spend(100, -5)],
        upcoming: const [],
        today: today,
      );
      final after = computeRunway(
        term: term,
        expenses: [spend(100, -5)],
        upcoming: const [],
        jarDeposits: [deposit(80, -2), deposit(20, 0)],
        today: today,
      );
      expect(after.putInJars, 100);
      expect(after.balance, before.balance - 100);
      expect(after.available, before.available - 100);
      // Not spending: the burn rate and today's spend don't move.
      expect(after.burnRate, before.burnRate);
      expect(after.spentToday, before.spentToday);
    });

    test('putting money in today comes out of today, like spending', () {
      final before = computeRunway(
        term: term,
        expenses: [spend(10, 0)],
        upcoming: const [],
        today: today,
      );
      final after = computeRunway(
        term: term,
        expenses: [spend(10, 0)],
        upcoming: const [],
        jarDeposits: [deposit(80, 0)],
        today: today,
      );
      expect(after.putInJarsToday, 80);
      expect(after.usedTodayAmount, 90);
      expect(after.dailyAllowance, closeTo(before.dailyAllowance, 1e-9));
      expect(
        after.safeToSpendToday,
        closeTo(before.safeToSpendToday - 80, 1e-9),
      );
      expect(after.spentToday, 10); // still not spending
    });

    test('money taken out today spreads over the days left', () {
      final s = computeRunway(
        term: term,
        expenses: const [],
        upcoming: const [],
        jarDeposits: [deposit(300, -30), deposit(-300, 0)],
        today: today,
      );
      expect(s.putInJarsToday, 0);
    });

    test('deposits from before this term already came out of it', () {
      final s = computeRunway(
        term: term,
        expenses: const [],
        upcoming: const [],
        jarDeposits: [deposit(200, -30), deposit(50, -1)],
        today: today,
      );
      expect(s.putInJars, 50);
      expect(s.balance, 950);
    });

    test('taking money out (buying or stopping) brings it back', () {
      final s = computeRunway(
        term: term,
        expenses: const [],
        upcoming: const [],
        // Saved 300 last term, took it all out today.
        jarDeposits: [deposit(300, -30), deposit(-300, 0)],
        today: today,
      );
      expect(s.putInJars, -300);
      expect(s.balance, 1300);
    });
  });

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

  group('savings goal', () {
    final flight = UpcomingCost(
      id: 'f',
      emoji: '✈️',
      name: 'Flight',
      amount: 300,
      dueDate: day(5),
    );

    test('is set aside like a big cost, so the daily budget skips it', () {
      final s = computeRunway(
        term: term.copyWith(savingsGoal: 200),
        expenses: [spend(100, -5)],
        upcoming: [flight],
        today: today,
      );
      expect(s.available, 400); // 900 − 300 flight − 200 savings
      expect(s.dailyAllowance, 40); // over 10 days
      expect(s.savingsKept, 200);
      expect(s.dippedIntoSavings, 0);
      expect(s.maxSavingsGoal, 600);
    });

    test('overspending eats savings before the big costs', () {
      final s = computeRunway(
        term: term.copyWith(savingsGoal: 200),
        expenses: [spend(550, -5)],
        upcoming: [flight],
        today: today,
      );
      // 450 left: the flight's 300 is covered, 150 of the 200 is still saved.
      expect(s.savingsKept, 150);
      expect(s.dippedIntoSavings, 50);
      expect(s.available, -50);
    });

    test('forecasts what the goal ends at, at the current pace', () {
      // 1000 over 19 days; spending $40/day on days −9..0.
      final expenses = [for (var d = -9; d <= 0; d++) spend(40, d)];
      final s = computeRunway(
        term: term.copyWith(savingsGoal: 300),
        expenses: expenses,
        upcoming: const [],
        today: today,
      );
      // 600 left; 9 more days after today at $40 = 360 more spent.
      expect(s.burnRate, 40);
      expect(s.dailyAllowance, 34); // (300 available + 40 today) / 10
      expect(s.projectedSavings, 240); // 300 + 300 + 40 − 400
      expect(s.onTrackToSave, isFalse);
      expect(s.savingsCutPerDay, 6);

      final slower = computeRunway(
        term: term.copyWith(savingsGoal: 300),
        expenses: [for (var d = -9; d <= 0; d++) spend(30, d)],
        upcoming: const [],
        today: today,
      );
      expect(slower.onTrackToSave, isTrue);
      expect(slower.projectedSavings, 300);
      expect(slower.savingsCutPerDay, 0);
    });

    test('streak counts goals hit in a row, newest first', () {
      SavedTerm t(double goal, double saved) => SavedTerm(
        name: 'M',
        period: BudgetPeriod.monthly,
        goal: goal,
        saved: saved,
      );
      expect(savingsStreak([t(100, 100), t(50, 50), t(50, 20), t(50, 50)]), 2);
      expect(savingsStreak([t(0, 0), t(50, 50)]), 0); // no goal, no streak
      expect(savingsStreak(const []), 0);
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

  group('nextMonth', () {
    Term month(double balance) => Term(
      name: 'October',
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 31),
      startingBalance: balance,
      period: BudgetPeriod.monthly,
    );
    Income salary({DateTime? endsOn}) => Income(
      id: 'salary',
      name: 'Salary',
      amount: 2000,
      frequency: IncomeFrequency.monthly,
      firstDate: DateTime(2026, 10, 25),
      endsOn: endsOn,
    );
    Expense spent(double amount) => Expense(
      id: 'e$amount',
      amount: amount,
      category: ExpenseCategory.other,
      isNeed: true,
      date: DateTime(2026, 10, 12, 9),
    );

    test('the goal is saved and only the rest carries over', () {
      final next = nextMonth(
        term: month(500).copyWith(savingsGoal: 100),
        expenses: [spent(360)],
        incomes: const [],
        today: DateTime(2026, 11, 3),
      )!;
      expect(next.saved, 100);
      expect(next.term.startingBalance, 40); // 500 − 360 − 100 saved
      expect(next.term.savingsGoal, 100); // the goal carries on
      expect(next.overspent, 0);
    });

    test('money put into a jar stays out of next month', () {
      final next = nextMonth(
        term: month(500),
        expenses: [spent(360)],
        incomes: const [],
        jarDeposits: [
          JarDeposit(
            id: 'd1',
            jarId: 'wallet',
            amount: 80,
            date: DateTime(2026, 10, 20),
          ),
        ],
        today: DateTime(2026, 11, 3),
      )!;
      expect(next.saved, 0);
      expect(next.term.startingBalance, 60); // 500 − 360 − 80 in the jar
    });

    test('leftover with no goal is spending money, not savings', () {
      final next = nextMonth(
        term: month(500),
        expenses: [spent(360)],
        incomes: const [],
        today: DateTime(2026, 11, 3),
      )!;
      expect(next.saved, 0);
      expect(next.term.startingBalance, 140);
    });

    test('spending into the goal saves less; unpaid costs come first', () {
      final next = nextMonth(
        term: month(500).copyWith(savingsGoal: 100),
        expenses: [spent(400)],
        incomes: const [],
        upcoming: [
          UpcomingCost(
            id: 'rent',
            emoji: '🏠',
            name: 'Rent',
            amount: 30,
            dueDate: DateTime(2026, 10, 30),
          ),
        ],
        today: DateTime(2026, 11, 3),
      )!;
      // 100 left; the unpaid 30 is still owed, so 70 of the goal is kept.
      expect(next.saved, 70);
      expect(next.term.startingBalance, 30); // pays the rent that moves over
    });

    test('only once a monthly budget\'s month is over', () {
      expect(
        nextMonth(
          term: term,
          expenses: const [],
          incomes: const [],
          today: day(30),
        ),
        isNull,
      );
      expect(
        nextMonth(
          term: month(100),
          expenses: const [],
          incomes: const [],
          today: DateTime(2026, 10, 31),
        ),
        isNull,
      );
    });

    test('leftover money starts the next calendar month', () {
      final next = nextMonth(
        term: month(1000),
        expenses: [spent(300)],
        incomes: [salary()],
        today: DateTime(2026, 11, 3),
      )!;
      expect(next.term.name, 'November');
      expect(next.term.start, DateTime(2026, 11, 1));
      expect(next.term.end, DateTime(2026, 11, 30));
      expect(next.term.period, BudgetPeriod.monthly);
      expect(next.term.startingBalance, 2700); // 1000 + 2000 − 300
      expect(next.overspent, 0);
    });

    test('months skipped while the app was closed still get paid', () {
      final next = nextMonth(
        term: month(0),
        expenses: [spent(500)],
        incomes: [salary()],
        today: DateTime(2027, 1, 4),
      )!;
      expect(next.term.name, 'January');
      expect(next.term.end, DateTime(2027, 1, 31));
      // October 1500, plus November's and December's paychecks.
      expect(next.term.startingBalance, 5500);
    });

    test('stopped pay and one-off money don\'t carry over', () {
      final stopped = salary(endsOn: DateTime(2026, 10, 26));
      final gift = Income(
        id: 'gift',
        name: 'Gift',
        amount: 50,
        frequency: IncomeFrequency.once,
        firstDate: DateTime(2026, 10, 3),
      );
      final weekly = Income(
        id: 'job',
        name: 'Job',
        amount: 100,
        frequency: IncomeFrequency.weekly,
        firstDate: DateTime(2026, 10, 2),
      );
      expect(
        continuingIncomes([stopped, gift, weekly], DateTime(2026, 10, 31)),
        [weekly],
      );
      final next = nextMonth(
        term: month(0),
        expenses: const [],
        incomes: [stopped, gift],
        today: DateTime(2026, 12, 1),
      )!;
      expect(next.term.startingBalance, 2050); // nothing added in November
    });

    test('overspending starts the month at zero and reports the gap', () {
      final next = nextMonth(
        term: month(100),
        expenses: [spent(150)],
        incomes: const [],
        today: DateTime(2026, 11, 1),
      )!;
      expect(next.term.startingBalance, 0);
      expect(next.overspent, 50);
    });

    test('spending exactly everything isn\'t a \$0.00 overspend', () {
      final next = nextMonth(
        term: month(0.30),
        expenses: [spent(0.10), spent(0.20)], // 0.1 + 0.2 != 0.3 in floats
        incomes: const [],
        today: DateTime(2026, 11, 1),
      )!;
      expect(next.overspent, 0);
      expect(next.term.startingBalance, 0);
    });

    test('a month that starts on the 31st runs to the end of the month', () {
      final next = nextMonth(
        term: Term(
          name: 'January',
          start: DateTime(2027, 1, 14),
          end: DateTime(2027, 1, 31),
          startingBalance: 10,
          period: BudgetPeriod.monthly,
        ),
        expenses: const [],
        incomes: const [],
        today: DateTime(2027, 2, 1),
      )!;
      expect(next.term.start, DateTime(2027, 2, 1));
      expect(next.term.end, DateTime(2027, 2, 28));
    });
  });

  group('billsDue', () {
    final rent = RepeatingBill(
      id: 'rent',
      emoji: '🏠',
      name: 'Rent',
      amount: 800,
      firstDue: DateTime(2026, 10, 31),
    );

    test('one per month, on the day or the last day of short months', () {
      final due = billsDue(
        rent,
        from: DateTime(2026, 10, 1),
        to: DateTime(2027, 3, 1),
      );
      expect(due.map((c) => c.dueDate), [
        DateTime(2026, 10, 31),
        DateTime(2026, 11, 30),
        DateTime(2026, 12, 31),
        DateTime(2027, 1, 31),
        DateTime(2027, 2, 28),
      ]);
      expect(due.map((c) => c.id).toSet(), hasLength(5));
      expect(due.every((c) => c.billId == 'rent' && c.amount == 800), isTrue);
    });

    test('only the months from [from] on', () {
      final due = billsDue(
        rent,
        from: DateTime(2026, 12, 1),
        to: DateTime(2026, 12, 31),
      );
      expect(due.single.id, 'rent@2026-12');
    });
  });

  group('summarize', () {
    Expense bought(double amount, ExpenseCategory c) => Expense(
      id: '$c$amount',
      amount: amount,
      category: c,
      isNeed: false,
      date: DateTime(2026, 9, 10, 12),
    );
    final job = Income(
      id: 'job',
      name: 'Job',
      amount: 100,
      frequency: IncomeFrequency.weekly,
      firstDate: DateTime(2026, 9, 4), // Fridays
    );
    final september = Term(
      name: 'September',
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 30),
      startingBalance: 500,
      period: BudgetPeriod.monthly,
    );

    test('started with, money in, spent, left, top categories', () {
      final s = summarize(
        PastTerm(
          term: september,
          endedOn: DateTime(2026, 10, 1, 8),
          expenses: [
            bought(40, ExpenseCategory.coffee),
            bought(120, ExpenseCategory.eatingOut),
            bought(15, ExpenseCategory.coffee),
            bought(60, ExpenseCategory.groceries),
            bought(5, ExpenseCategory.transit),
          ],
          incomes: [job],
        ),
      );
      expect(s.startedWith, 500);
      expect(s.moneyIn, 400); // Sep 4, 11, 18, 25
      expect(s.spent, 240);
      expect(s.left, 660);
      expect(s.topCategories.map((c) => (c.category.category, c.amount)), [
        (ExpenseCategory.eatingOut, 120.0),
        (ExpenseCategory.groceries, 60.0),
        (ExpenseCategory.coffee, 55.0),
      ]);
    });

    test('ended early: pay after that day never arrived', () {
      final s = summarize(
        PastTerm(
          term: september,
          endedOn: DateTime(2026, 9, 12, 18),
          expenses: [bought(700, ExpenseCategory.travel)],
          incomes: [job],
        ),
      );
      expect(s.moneyIn, 200); // Sep 4 and 11 only
      expect(s.left, 0); // 500 + 200 − 700
    });

    test('overspending shows as a negative amount left', () {
      final s = summarize(
        PastTerm(
          term: september,
          endedOn: DateTime(2026, 10, 1),
          expenses: [bought(650, ExpenseCategory.shopping)],
          incomes: const [],
        ),
      );
      expect(s.left, -150);
    });
  });

  group('biggestChange', () {
    Expense spend(String id, double amount, ExpenseCategory c, int month) =>
        Expense(
          id: id,
          amount: amount,
          category: c,
          isNeed: c == ExpenseCategory.groceries,
          date: DateTime(2026, month, 10, 12),
        );
    PastTerm month(int m, String name, List<Expense> expenses) => PastTerm(
      term: Term(
        name: name,
        start: DateTime(2026, m, 1),
        end: DateTime(2026, m + 1, 0),
        startingBalance: 1000,
        period: BudgetPeriod.monthly,
      ),
      endedOn: DateTime(2026, m + 1, 1, 9),
      expenses: expenses,
      incomes: const [],
    );

    test('the biggest drop wins, per day so month lengths are fair', () {
      final september = month(9, 'September', [
        spend('a', 300, ExpenseCategory.delivery, 9), // $10/day over 30
        spend('b', 150, ExpenseCategory.groceries, 9),
      ]);
      final october = month(10, 'October', [
        spend('c', 217, ExpenseCategory.delivery, 10), // $7/day over 31
        spend('d', 310, ExpenseCategory.groceries, 10),
      ]);
      final c = biggestChange(october, september)!;
      expect(c.category, const CategoryRef(ExpenseCategory.delivery));
      expect(c.change, closeTo(-0.3, 1e-9));
    });

    test('if nothing fell, the biggest rise', () {
      final september = month(9, 'September', [
        spend('a', 300, ExpenseCategory.eatingOut, 9),
      ]);
      final october = month(10, 'October', [
        spend('b', 465, ExpenseCategory.eatingOut, 10), // $15/day vs $10
      ]);
      expect(biggestChange(october, september)!.change, closeTo(0.5, 1e-9));
    });

    test('small moves and small categories aren\'t news', () {
      final september = month(9, 'September', [
        spend('a', 300, ExpenseCategory.groceries, 9),
        spend('b', 9, ExpenseCategory.coffee, 9), // under $10 before
      ]);
      final october = month(10, 'October', [
        spend('c', 300, ExpenseCategory.groceries, 10), // −3% per day
        spend('d', 90, ExpenseCategory.coffee, 10),
      ]);
      expect(biggestChange(october, september), isNull);
    });

    test('a custom category is its own line, even after a rename', () {
      const smoke = CustomCategory(id: 'c1', emoji: '🚬', name: 'Smokes');
      Expense custom(String id, double amount, int m, CustomCategory c) =>
          Expense(
            id: id,
            amount: amount,
            category: ExpenseCategory.other,
            isNeed: false,
            date: DateTime(2026, m, 10, 12),
            custom: c,
          );
      final september = month(9, 'September', [
        custom('a', 300, 9, smoke),
        spend('b', 100, ExpenseCategory.other, 9),
      ]);
      final october = month(10, 'October', [
        custom('c', 155, 10, smoke.copyWith(name: 'Cigarettes')),
        spend('d', 100, ExpenseCategory.other, 10),
      ]);
      final top = summarize(september).topCategories;
      expect(top.map((c) => (c.category.label, c.amount)), [
        ('Smokes', 300.0),
        ('Other', 100.0),
      ]);
      final c = biggestChange(october, september)!;
      expect(c.category.custom?.id, 'c1');
      expect(c.change, closeTo(-0.5, 1e-9));
    });

    test('needs share of what was spent', () {
      final s = summarize(
        month(10, 'October', [
          spend('a', 75, ExpenseCategory.groceries, 10),
          spend('b', 25, ExpenseCategory.fun, 10),
        ]),
      );
      expect(s.needShare, 0.75);
    });
  });
}
