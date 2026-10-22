import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/coach.dart';
import 'package:runway/app/models.dart';

void main() {
  // available $1,000 → trade ceiling $120; safe today $20.
  const g = CoachGrounding(
    available: 1000,
    safeToSpendToday: 20,
    dailyAllowance: 25,
    spentToday: 5,
    daysLeft: 40,
    burnRate: 30,
    daysShort: 0,
  );

  group('assess', () {
    test('yes when it fits in safe-to-spend today', () {
      final a = assess(20, 'boba', g);
      expect(a.verdict, Verdict.yes);
      expect(a.dailyAfter, a.dailyBefore);
      expect(a.runwayDaysLost, 0);
    });

    test('trade when within 12% of available', () {
      final a = assess(60, 'concert ticket', g);
      expect(a.verdict, Verdict.trade);
      expect(a.message, contains('skip 3 delivery orders'));
      expect(a.dailyBefore, 25);
      expect(a.dailyAfter, closeTo((1000 - 60 + 5) / 40, 1e-9));
      expect(a.runwayDaysLost, closeTo(2, 1e-9));
    });

    test('trade boundary is inclusive at exactly 12%', () {
      expect(assess(120, 'x', g).verdict, Verdict.trade);
      expect(assess(120.01, 'x', g).verdict, Verdict.no);
    });

    test('a tiny trade still asks for at least one skipped order', () {
      expect(assess(21, 'x', g).message, contains('skip 1 delivery order '));
    });

    test('not this term above the trade ceiling, suggests a goal', () {
      final a = assess(600, 'trip', g);
      expect(a.verdict, Verdict.no);
      expect(a.headline, 'Not this term');
      // $25/day allowance: $5 a day steady (120 days), $8 a day faster.
      expect(a.plan!.perDay, 5);
      expect(a.plan!.howLong, '4 months');
      expect(a.fasterPlan!.perDay, 8);
      expect(a.fasterPlan!.howLong, '3 months');
      expect(
        a.message,
        'That would eat 60% of what you have left. Put \$5 a day aside and '
        'you\'ll have it in 4 months, or \$8 a day to get it in 3 months.',
      );
      expect(a.runwayDaysLost, closeTo(20, 1e-9));
    });

    test('a big daily allowance never plans more than the price', () {
      // The old rule said "put \$557/week aside, have it in 1 week" here.
      const flush = CoachGrounding(
        available: 3600,
        safeToSpendToday: 400,
        dailyAllowance: 400,
        spentToday: 0,
        daysLeft: 9,
        burnRate: 100,
        daysShort: 0,
        period: BudgetPeriod.monthly,
      );
      final a = assess(500, 'Dior wallet', flush);
      expect(a.verdict, Verdict.no);
      expect(a.plan!.perDay, 80);
      expect(a.plan!.howLong, '7 days');
      expect(
        a.message,
        'That would eat 14% of what you have left. Put \$80 a day aside and '
        'you\'ll have it in 7 days, before this month ends, or \$135 a day '
        'to get it in 4 days.',
      );
    });

    test('more than everything left says so', () {
      final a = assess(5000, 'car', g);
      expect(a.message, startsWith('That\'s more than the \$1,000 you have'));
    });

    test('a monthly budget says "not this month"', () {
      const monthly = CoachGrounding(
        available: 1000,
        safeToSpendToday: 20,
        dailyAllowance: 25,
        spentToday: 5,
        daysLeft: 20,
        burnRate: 30,
        daysShort: 0,
        period: BudgetPeriod.monthly,
      );
      expect(assess(600, 'trip', monthly).headline, 'Not this month');
      expect(monthly.toJson()['period'], 'month');
    });

    test('nothing is affordable when already over budget', () {
      const broke = CoachGrounding(
        available: 0,
        safeToSpendToday: -10,
        dailyAllowance: 0,
        spentToday: 10,
        daysLeft: 10,
        burnRate: 30,
        daysShort: 30,
      );
      final a = assess(1, 'gum', broke);
      expect(a.verdict, Verdict.no);
      expect(a.plan, isNull);
      expect(a.message, contains('nothing spare to save'));
    });
  });

  group('parseQuestion', () {
    test('reads the chips', () {
      expect(parseQuestion('Concert ticket \$60'), (
        amount: 60.0,
        item: 'Concert ticket',
      ));
      expect(parseQuestion('AirPods \$129'), (amount: 129.0, item: 'AirPods'));
      expect(parseQuestion('Dinner out \$25')?.amount, 25);
    });

    test('handles cents, commas and phrasing', () {
      expect(parseQuestion('Can I afford a \$1,299.99 laptop?'), (
        amount: 1299.99,
        item: 'laptop',
      ));
      expect(parseQuestion('shoes for 80')?.amount, 80);
    });

    test('returns null without an amount', () {
      expect(parseQuestion('should I buy shoes'), isNull);
      expect(parseQuestion('\$0'), isNull);
    });
  });

  group('purchaseWithoutPrice', () {
    test('finds the item when a purchase has no price', () {
      expect(
        purchaseWithoutPrice('Can I afford a Dior wallet?'),
        'Dior wallet',
      );
      expect(purchaseWithoutPrice('should i get boba'), 'boba');
      expect(purchaseWithoutPrice('is it worth it to buy a ps5?'), 'ps5');
      expect(purchaseWithoutPrice('can I afford it'), 'it');
    });

    test('leaves priced and budget questions alone', () {
      expect(purchaseWithoutPrice('Dior wallet \$450'), isNull);
      expect(purchaseWithoutPrice('AirPods 129'), isNull);
      expect(
        purchaseWithoutPrice('How much can I afford to spend this week?'),
        isNull,
      );
      expect(purchaseWithoutPrice('how do i get my savings up?'), isNull);
      expect(purchaseWithoutPrice('How am I doing on food?'), isNull);
    });
  });

  test('a number inside a name isn\'t a price', () {
    expect(parseQuestion('is it worth it to buy a ps5?'), isNull);
    expect(parseQuestion('ps5 400')?.amount, 400);
  });

  test('LocalCoach asks what an unpriced purchase costs', () async {
    final reply = await const LocalCoach().ask(
      'Can I afford a Dior wallet?',
      g,
    );
    expect(reply.assessment, isNull);
    expect(reply.text, startsWith('How much is the Dior wallet?'));
  });

  test('LocalCoach asks for a price when none is given', () async {
    final reply = await const LocalCoach().ask('hmm', g);
    expect(reply.assessment, isNull);
    expect(reply.text, isNotEmpty);
  });
}
