// Numbers at the edges: zero, a cent, the biggest amount an input allows,
// absurd values from voice, links or the coach's text box, and values that
// aren't numbers at all. Nothing here should crash or show nonsense.
import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/app_state.dart';
import 'package:runway/app/auth.dart';
import 'package:runway/app/budget_math.dart';
import 'package:runway/app/coach.dart';
import 'package:runway/app/format.dart';
import 'package:runway/app/models.dart';
import 'package:runway/app/purchase_link.dart';
import 'package:runway/app/repository.dart';
import 'package:runway/app/split_math.dart';
import 'package:runway/app/spoken_expense.dart';
import 'package:runway/widgets/form_fields.dart';

const _bad = [0.0, -0.01, -50.0, 1000000.0, 1e12, double.nan, double.infinity];

void main() {
  group('money()', () {
    test('formats ordinary amounts with commas and cents', () {
      expect(money(0), '\$0.00');
      expect(money(0.01), '\$0.01');
      expect(money(1000), '\$1,000.00');
      expect(money(999999.99), '\$999,999.99');
      expect(money(1234567, cents: false), '\$1,234,567');
      expect(money(-12.5), '−\$12.50');
    });

    test('never shows minus zero for amounts that round to nothing', () {
      expect(money(-0.004), '\$0.00');
      expect(money(-0.0), '\$0.00');
      expect(money(-0.4, cents: false), '\$0');
      expect(money(-0.005), '−\$0.01');
    });

    test('huge values keep every digit instead of exponents', () {
      expect(money(1e21), '\$1,000,000,000,000,000,000,000.00');
      expect(money(-1e30, cents: false), startsWith('−\$1,000,000,'));
      expect(money(1e30), isNot(contains('e')));
    });

    test('values that are not numbers show a dash, not NaN', () {
      expect(money(double.nan), '—');
      expect(money(double.infinity), '—');
      expect(money(double.negativeInfinity, cents: false), '—');
    });
  });

  group('amount inputs', () {
    TextEditingValue type(String text) => amountInputFormatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: text),
    );

    test('allow up to \$999,999.99 and nothing more', () {
      expect(type('999999.99').text, '999999.99');
      expect(type('1000000').text, isNot('1000000'));
      expect(type('12.345').text, isNot('12.345'));
      expect(type('-5').text, isNot('-5'));
      expect(type('1e9').text, isNot('1e9'));
    });

    test('unreadable or partial text counts as 0', () {
      expect(parseAmountInput(''), 0);
      expect(parseAmountInput('.'), 0);
      expect(parseAmountInput('abc'), 0);
      expect(parseAmountInput('12.'), 12);
      expect(parseAmountInput('.5'), 0.5);
    });

    test('amountText round-trips whole and cent amounts', () {
      expect(amountText(12), '12');
      expect(amountText(12.5), '12.50');
      expect(amountText(0.01), '0.01');
      expect(amountText(999999.99), '999999.99');
    });
  });

  group('runway maths at the edges', () {
    final start = DateTime(2026, 9, 1);
    final end = DateTime(2026, 12, 11);
    Term term({double balance = 1000, double goal = 0}) => Term(
      name: 'Fall',
      start: start,
      end: end,
      startingBalance: balance,
      savingsGoal: goal,
    );
    Expense spent(double amount, DateTime date) => Expense(
      id: 'e$amount${date.day}',
      amount: amount,
      category: ExpenseCategory.other,
      isNeed: true,
      date: date,
    );

    test('no money at all: nothing to spend, nothing breaks', () {
      final s = computeRunway(
        term: term(balance: 0),
        expenses: const [],
        upcoming: const [],
        today: DateTime(2026, 10, 1),
      );
      expect(s.dailyAllowance, 0);
      expect(s.safeToSpendToday, 0);
      expect(s.covered, isTrue);
      expect(money(s.safeToSpendToday), '\$0.00');
    });

    test(
      'a cent spent against the biggest balance has no out-of-range date',
      () {
        final s = computeRunway(
          term: term(balance: 999999.99),
          expenses: [spent(0.01, start)],
          upcoming: const [],
          today: DateTime(2026, 12, 1),
        );
        expect(s.runwayDays, RunwaySnapshot.maxRunwayDays);
        expect(() => s.runwayDate, returnsNormally);
        expect(s.covered, isTrue);
      },
    );

    test(
      'overspent: money ran out today, and days short counts to the end',
      () {
        final today = DateTime(2026, 10, 1);
        final s = computeRunway(
          term: term(balance: 100),
          expenses: [spent(500, today)],
          upcoming: const [],
          today: today,
        );
        expect(s.available, -400);
        expect(s.runwayDays, 0);
        expect(s.runwayDate, today);
        expect(s.daysShort, daysBetween(today, end));
        expect(s.safeToSpendToday, lessThan(0));
      },
    );

    test('before the term starts and after it ends, days never hit zero', () {
      for (final today in [DateTime(2026, 1, 1), DateTime(2027, 6, 1)]) {
        final s = computeRunway(
          term: term(),
          expenses: [spent(10, start)],
          upcoming: const [],
          today: today,
        );
        expect(s.daysLeft, greaterThanOrEqualTo(1));
        expect(s.daysElapsed, greaterThanOrEqualTo(1));
        expect(s.dailyAllowance.isFinite, isTrue);
        expect(s.burnRate.isFinite, isTrue);
        expect(s.termProgress(today), inInclusiveRange(0, 1));
      }
    });

    test('a one-day term spreads everything over that one day', () {
      final day = DateTime(2026, 10, 1);
      final s = computeRunway(
        term: Term(
          name: 'One day',
          start: day,
          end: day.add(const Duration(days: 1)),
          startingBalance: 50,
        ),
        expenses: const [],
        upcoming: const [],
        today: day.add(const Duration(days: 1)),
      );
      expect(s.daysLeft, 1);
      expect(s.dailyAllowance, 50);
    });

    test('big costs bigger than the balance leave available negative', () {
      final s = computeRunway(
        term: term(balance: 100),
        expenses: const [],
        upcoming: [
          UpcomingCost(
            id: 'c',
            emoji: '✈️',
            name: 'Flight',
            amount: 900,
            dueDate: DateTime(2026, 12, 1),
          ),
        ],
        today: DateTime(2026, 10, 1),
      );
      expect(s.available, -800);
      expect(s.maxSavingsGoal, 0);
      expect(s.dailyAllowance, lessThan(0));
    });

    test('splitting a cent or two never makes a negative share', () {
      for (final total in [0.01, 0.02, 0.03, 999999.99]) {
        for (final others in [1, 2, 7]) {
          final split = splitEvenly(total, others);
          expect(split.each, greaterThanOrEqualTo(0));
          expect(split.mine, greaterThanOrEqualTo(0));
          expect(split.mine + split.each * others, closeTo(total, 0.005));
        }
      }
    });
  });

  group('AppState refuses impossible amounts', () {
    final now = DateTime(2026, 10, 2, 15);
    AppState build() => AppState(
      repository: MockBudgetRepository(now: now),
      data: MockBudgetRepository.seed(now),
      user: const UserProfile(name: 'Alex', email: 'alex@uni.edu'),
      clock: () => now,
    );

    void refuses(
      String what,
      void Function(AppState s, double v) call, {
      bool zeroMeansNone = false,
    }) {
      test(what, () {
        for (final v in _bad) {
          if (zeroMeansNone && v == 0) continue;
          final state = build();
          final expenses = state.recentExpenses(1000).length;
          final balance = state.snapshot.balance;
          expect(() => call(state, v), throwsArgumentError, reason: '$v');
          expect(state.recentExpenses(1000).length, expenses, reason: '$v');
          expect(state.snapshot.balance, balance, reason: '$v');
        }
      });
    }

    refuses(
      'an expense',
      (s, v) => s.addExpense(
        amount: v,
        category: ExpenseCategory.coffee,
        isNeed: false,
      ),
    );
    refuses(
      'money coming in',
      (s, v) => s.addIncome(
        name: 'Job',
        amount: v,
        frequency: IncomeFrequency.weekly,
        firstDate: now,
      ),
    );
    refuses(
      'a big cost',
      (s, v) => s.addUpcomingCost(
        UpcomingCost(
          id: 'c',
          emoji: '✈️',
          name: 'Flight',
          amount: v,
          dueDate: now.add(const Duration(days: 9)),
        ),
      ),
    );
    refuses('a jar', (s, v) => s.startJar(name: 'Bike', target: v));
    refuses('a split bill', (s, v) {
      s.splitBill(
        description: 'Pizza',
        total: v,
        roommates: s.friends.take(2).toList(),
        category: ExpenseCategory.eatingOut,
        isNeed: false,
      );
    });
    refuses(
      'an IOU',
      (s, v) => s.addLocalIous(description: 'Taxi', owed: {'Sam': v}),
      // Owing $0 means owing nothing: skipped, not an error.
      zeroMeansNone: true,
    );
    refuses(
      'my share of an IOU',
      (s, v) => s.addLocalIous(
        description: 'Taxi',
        owed: const {'Sam': 5},
        myShare: v,
      ),
      zeroMeansNone: true,
    );
    refuses(
      'a term with impossible starting money',
      (s, v) => s.updateTerm(
        Term(
          name: 'Fall',
          start: s.term.start,
          end: s.term.end,
          startingBalance: v == 0 ? -1 : v,
        ),
      ),
    );
    refuses(
      'a new term with impossible starting money',
      (s, v) => s.startTerm(
        Term(
          name: 'Spring',
          start: now,
          end: now.add(const Duration(days: 90)),
          startingBalance: v == 0 ? -1 : v,
        ),
        const [],
      ),
    );

    test('a new term must end after it starts', () {
      final state = build();
      expect(
        () => state.startTerm(
          Term(name: 'Spring', start: now, end: now, startingBalance: 10),
          const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => state.startTerm(
          Term(
            name: '  ',
            start: now,
            end: now.add(const Duration(days: 1)),
            startingBalance: 10,
          ),
          const [],
        ),
        throwsArgumentError,
      );
    });

    test('a savings goal can\'t be negative or not a number', () {
      final state = build();
      for (final v in [-1.0, double.nan, double.infinity]) {
        expect(() => state.setSavingsGoal(v), throwsArgumentError);
      }
      state.setSavingsGoal(1e9);
      expect(
        state.term.savingsGoal,
        closeTo(state.snapshot.maxSavingsGoal, 0.005),
      );
    });

    test('friend splits must add up to the total', () {
      final state = build();
      Future<void> split(int total, Map<String, int> shares) =>
          state.splitWithFriends(
            description: 'Dinner',
            totalCents: total,
            paidBy: 'me',
            kind: SplitKind.equal,
            shares: shares,
            category: ExpenseCategory.eatingOut,
            isNeed: false,
          );
      expect(() => split(1000, {'a': 400, 'b': 500}), throwsArgumentError);
      expect(() => split(0, const {}), throwsArgumentError);
      expect(() => split(100, {'a': 150, 'b': -50}), throwsArgumentError);
      expect(() => split(100000000, {'a': 100000000}), throwsArgumentError);
    });

    test('the smallest and biggest amounts are accepted', () {
      final state = build();
      final before = state.snapshot.balance;
      state.addExpense(
        amount: 0.01,
        category: ExpenseCategory.coffee,
        isNeed: false,
      );
      state.addExpense(
        amount: 999999.99,
        category: ExpenseCategory.other,
        isNeed: true,
      );
      expect(state.snapshot.balance, closeTo(before - 1000000, 0.001));
      expect(money(state.snapshot.safeToSpendToday), isNot(contains('e')));
    });

    test('a few cents split many ways adds no \$0 IOUs or expenses', () {
      final state = build();
      final splits = state.splits.length;
      final expenses = state.recentExpenses(1000).length;
      state.splitBill(
        description: 'Gum',
        total: 0.01,
        roommates: state.friends.take(2).toList(),
        category: ExpenseCategory.other,
        isNeed: false,
      );
      expect(state.splits.length, splits);
      expect(state.recentExpenses(1000).length, expenses + 1);
      expect(state.recentExpenses(1).single.amount, 0.01);

      state.splitBill(
        description: 'Gum',
        total: 0.02,
        roommates: state.friends.take(2).toList(),
        category: ExpenseCategory.other,
        isNeed: false,
      );
      expect(state.splits.length, splits + 2);
      expect(state.splits.take(2).every((s) => s.amount == 0.01), isTrue);
      expect(state.recentExpenses(1000).length, expenses + 1);
    });

    test('a jar never takes more than there is to spend', () {
      final state = build();
      final jar = state.startJar(name: 'Laptop', target: 999999);
      final spendable = state.snapshot.available;
      state.putIntoJar(jar.id, 999998);
      expect(state.jar(jar.id)!.saved, closeTo(spendable, 0.005));
      expect(state.snapshot.available, greaterThanOrEqualTo(-0.005));
      state.takeOutOfJar(jar.id, 999998);
      expect(state.jar(jar.id)!.saved, 0);
    });
  });

  group('amounts from text', () {
    const g = CoachGrounding(
      available: 1000,
      safeToSpendToday: 20,
      dailyAllowance: 25,
      spentToday: 5,
      daysLeft: 40,
      burnRate: 30,
      daysShort: 0,
    );

    test('the coach ignores absurd and zero prices', () {
      expect(parseQuestion('a yacht for \$999999999999999999999999'), isNull);
      expect(parseQuestion('\$1000000000 house'), isNull);
      expect(parseQuestion('\$0 gum'), isNull);
      expect(parseQuestion('\$0.001 gum'), isNull);
      expect(parseQuestion('\$999,999,999 island')?.amount, 999999999);
    });

    test('a huge price gets a sensible "not this term" answer', () {
      final a = assess(999999999, 'island', g);
      expect(a.verdict, Verdict.no);
      expect(a.message, isNot(contains('NaN')));
      expect(a.message, isNot(contains('Infinity')));
      expect(a.message, isNot(contains('e+')));
    });

    test('a cent always fits', () {
      expect(assess(0.01, 'gum', g).verdict, Verdict.yes);
    });

    test('purchase links drop amounts that are zero, negative or too big', () {
      expect(ApplePayPurchase.parseAmount('0'), isNull);
      expect(ApplePayPurchase.parseAmount('-5'), 5);
      expect(ApplePayPurchase.parseAmount('100000'), isNull);
      expect(ApplePayPurchase.parseAmount('abc'), isNull);
      expect(ApplePayPurchase.parseAmount(''), isNull);
      expect(ApplePayPurchase.parseAmount('99999.999'), isNull);
      expect(ApplePayPurchase.parseAmount('0.004'), isNull);
    });

    test('voice drops amounts too big to be one purchase', () {
      expect(SpokenExpense.parse('150000 dollars on rent').amount, isNull);
      expect(SpokenExpense.parse('0 dollars on coffee').amount, isNull);
      expect(SpokenExpense.parse('4.50 on coffee').amount, 4.5);
    });
  });
}
