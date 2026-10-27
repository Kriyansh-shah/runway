import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/budget_math.dart';
import 'package:runway/app/models.dart';
import 'package:runway/app/spending_lookup.dart';
import 'package:runway/app/week_recap.dart';

void main() {
  final today = DateTime(2026, 10, 27, 15); // a Tuesday
  final term = Term(
    name: 'Fall',
    start: DateTime(2026, 10, 1),
    end: DateTime(2026, 12, 15),
    startingBalance: 2000,
  );

  Expense spend(
    double amount,
    DateTime day, {
    ExpenseCategory c = ExpenseCategory.coffee,
    String? note,
    bool planned = false,
  }) => Expense(
    id: '$amount@$day',
    amount: amount,
    category: c,
    isNeed: false,
    date: day.add(const Duration(hours: 12)),
    note: note,
    planned: planned,
  );

  final expenses = [
    spend(5, DateTime(2026, 10, 12)), // the week before last
    spend(4.5, DateTime(2026, 10, 19), note: 'Latte'),
    spend(30, DateTime(2026, 10, 20), c: ExpenseCategory.delivery),
    spend(6, DateTime(2026, 10, 22)),
    spend(400, DateTime(2026, 10, 23), c: ExpenseCategory.other, planned: true),
    spend(12, DateTime(2026, 10, 26), c: ExpenseCategory.groceries),
  ];
  final ledger = dailyLedger(
    term: term,
    expenses: expenses,
    upcoming: const [],
    today: today,
  );
  final history = SpendingHistory(
    expenses: expenses,
    ledger: ledger,
    today: today,
    termStart: term.start,
  );

  group('lookUp', () {
    test('weeks run Sunday to Saturday, like the calendar', () {
      final r = history.range(LookupPeriod.lastWeek)!;
      expect(r.from, DateTime(2026, 10, 18));
      expect(r.to, DateTime(2026, 10, 24));
      expect(
        history.range(LookupPeriod.thisWeek)!.from,
        DateTime(2026, 10, 25),
      );
    });

    test('last week: totals, categories, biggest, days over budget', () {
      final found = history.lookUp(period: 'lastWeek');
      expect(found['period'], 'Oct 18 – Oct 24');
      expect(found['spent'], 40.5);
      expect(found['billsPaidFromMoneySetAside'], 400);
      expect(found['expensesLogged'], 3);
      expect(found['byCategory'], {'Delivery': 30, 'Coffee': 10.5});
      expect((found['biggest']! as List).first, {
        'what': 'Delivery',
        'amount': 30.0,
        'on': 'Oct 20',
      });
      expect(found['daysCounted'], 7);
      // The \$30 delivery was more than that day's budget.
      expect(found['daysOverBudget'], 1);
    });

    test('one category, matched loosely or by note', () {
      expect(
        history.lookUp(period: 'lastWeek', category: 'Coffee')['spent'],
        10.5,
      );
      expect(
        history.lookUp(period: 'wholeTerm', category: 'latte')['spent'],
        4.5,
      );
      final none = history.lookUp(period: 'lastWeek', category: 'Uber');
      expect(none['note'], contains('Nothing logged'));
      expect(none['categoriesUsed'], containsAll(['Coffee', 'Delivery']));
    });

    test('one day, and days outside the budget', () {
      expect(
        history.lookUp(period: 'oneDay', day: '2026-10-26')['period'],
        'Monday, Oct 26',
      );
      expect(
        history.lookUp(period: 'oneDay', day: '2026-09-15')['note'],
        contains('before this budget started'),
      );
      expect(history.lookUp(period: 'nextYear')['error'], isNotNull);
    });
  });

  group('answerSpendingQuestion', () {
    test('a category and a period', () {
      expect(
        answerSpendingQuestion(
          'How much did I spend on coffee last week?',
          history,
        ),
        'You spent \$10.50 on coffee last week, across 2 expenses. '
        'The biggest was Coffee at \$6.00 on Oct 22.',
      );
    });

    test('everything so far, with where most of it went', () {
      expect(
        answerSpendingQuestion('What have I spent?', history),
        allOf(
          startsWith('You spent \$57.50 so far, across 5 expenses.'),
          endsWith('Most of it went to Delivery (\$30.00).'),
        ),
      );
    });

    test('nothing to do with spending: not answered', () {
      expect(answerSpendingQuestion('How is my week going?', history), isNull);
    });
  });

  group('lastWeekRecap', () {
    test('adds up last week against its daily budgets', () {
      final week = lastWeekRecap(
        ledger: ledger,
        expenses: expenses,
        today: today,
      )!;
      expect(week.start, DateTime(2026, 10, 18));
      expect(week.days, 7);
      expect(week.spent, 40.5);
      expect(week.noSpendDays, 4);
      expect(week.topCategory, (name: 'Delivery', spent: 30.0));
      expect(week.biggest, (what: 'Delivery', amount: 30.0));
      expect(week.weekBefore, 5);
      expect(week.change, '710% more');
      final budget = [
        for (final d in ledger)
          if (!d.day.isBefore(week.start) && !d.day.isAfter(week.end))
            d.allowance,
      ].fold<double>(0, (s, a) => s + a);
      expect(week.budget, closeTo(budget, 1e-9));
      expect(week.summary, startsWith('You spent \$40.50 of your'));
      expect(week.summary, contains('Delivery was your biggest category'));
      expect(week.toFacts()['underBudgetBy'], isA<double>());
    });

    test('none until 3 days of a week are inside the budget', () {
      expect(
        lastWeekRecap(
          ledger: ledger,
          expenses: expenses,
          // The budget began Thursday Oct 1: last week had none of it.
          today: DateTime(2026, 10, 2),
        ),
        isNull,
      );
    });
  });
}
