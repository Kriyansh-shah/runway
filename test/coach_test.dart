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
      expect(a.message, contains('/week'));
      expect(a.runwayDaysLost, closeTo(20, 1e-9));
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
      expect(assess(1, 'gum', broke).verdict, Verdict.no);
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

  test('LocalCoach asks for a price when none is given', () async {
    final reply = await const LocalCoach().ask('hmm', g);
    expect(reply.assessment, isNull);
    expect(reply.text, isNotEmpty);
  });
}
