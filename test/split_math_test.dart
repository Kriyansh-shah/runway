import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/split_math.dart';

SharedExpense split(
  String paidBy,
  Map<String, int> shares, {
  String? squad,
  bool deleted = false,
}) => SharedExpense(
  id: '$paidBy-${shares.hashCode}',
  paidBy: paidBy,
  description: 'x',
  totalCents: shares.values.fold(0, (a, b) => a + b),
  shares: shares,
  createdAt: DateTime(2026, 10, 21),
  squadId: squad,
  deleted: deleted,
);

Settlement paid(String from, String to, int cents, {String? squad}) =>
    Settlement(
      id: '$from$to$cents',
      from: from,
      to: to,
      amountCents: cents,
      createdAt: DateTime(2026, 10, 21),
      squadId: squad,
    );

void main() {
  group('computeShares', () {
    test('equally, with the leftover cent to the payer', () {
      final s = computeShares(
        totalCents: 1000,
        people: ['me', 'ann', 'ben'],
        kind: SplitKind.equal,
        roundingTo: 'me',
      );
      expect(s, {'me': 334, 'ann': 333, 'ben': 333});
    });

    test('exact amounts must add up to the total', () {
      expect(
        computeShares(
          totalCents: 3000,
          people: ['me', 'ann'],
          kind: SplitKind.exact,
          inputs: {'me': 1000, 'ann': 2000},
        ),
        {'me': 1000, 'ann': 2000},
      );
      expect(
        () => computeShares(
          totalCents: 3000,
          people: ['me', 'ann'],
          kind: SplitKind.exact,
          inputs: {'me': 1000, 'ann': 1500},
        ),
        throwsA(
          isA<SplitInputException>().having(
            (e) => e.message,
            'message',
            '\$5.00 still to assign.',
          ),
        ),
      );
    });

    test('percentages must make 100 and round to whole cents', () {
      final s = computeShares(
        totalCents: 1000,
        people: ['me', 'ann', 'ben'],
        kind: SplitKind.percent,
        inputs: {'me': 33.33, 'ann': 33.33, 'ben': 33.34},
        roundingTo: 'me',
      );
      expect(s.values.reduce((a, b) => a + b), 1000);
      expect(s['ben'], 334);
      expect(
        () => computeShares(
          totalCents: 1000,
          people: ['me', 'ann'],
          kind: SplitKind.percent,
          inputs: {'me': 50, 'ann': 40},
        ),
        throwsA(isA<SplitInputException>()),
      );
    });

    test('shares split by weight (2 nights vs 1)', () {
      expect(
        computeShares(
          totalCents: 9000,
          people: ['me', 'ann'],
          kind: SplitKind.shares,
          inputs: {'me': 2, 'ann': 1},
        ),
        {'me': 6000, 'ann': 3000},
      );
    });

    test('a zero weight pays nothing and gets no rounding cent', () {
      final s = computeShares(
        totalCents: 1001,
        people: ['me', 'ann', 'ben'],
        kind: SplitKind.shares,
        inputs: {'me': 1, 'ann': 1, 'ben': 0},
      );
      expect(s['ben'], 0);
      expect(s['me']! + s['ann']!, 1001);
    });

    test('needs someone to split with and a cost', () {
      expect(
        () => computeShares(
          totalCents: 100,
          people: ['me'],
          kind: SplitKind.equal,
        ),
        throwsA(isA<SplitInputException>()),
      );
    });
  });

  group('balances', () {
    test('I paid: they owe me their parts', () {
      final b = balances(
        me: 'me',
        expenses: [
          split('me', {'me': 1000, 'ann': 1000, 'ben': 1000}),
        ],
        settlements: const [],
      );
      expect(b, {'ann': 1000, 'ben': 1000});
    });

    test('they paid: I owe them my part', () {
      final b = balances(
        me: 'me',
        expenses: [
          split('ann', {'ann': 1500, 'me': 1500}),
        ],
        settlements: const [],
      );
      expect(b, {'ann': -1500});
    });

    test('splits both ways net out to one balance per friend', () {
      final b = balances(
        me: 'me',
        expenses: [
          split('me', {'me': 2000, 'ann': 2000}),
          split('ann', {'ann': 500, 'me': 500}),
        ],
        settlements: const [],
      );
      expect(b, {'ann': 1500});
    });

    test('settling up clears it; deleted splits never counted', () {
      final b = balances(
        me: 'me',
        expenses: [
          split('me', {'me': 2000, 'ann': 2000}),
          split('ann', {'ann': 900, 'me': 900}, deleted: true),
        ],
        settlements: [paid('ann', 'me', 2000)],
      );
      expect(b, isEmpty);
    });

    test('simplify debts redraws a squad as the fewest payments', () {
      // Ann owes Ben 10, Ben owes Cat 10.
      final expenses = [
        split('ben', {'ben': 0, 'ann': 1000}, squad: 'apt'),
        split('cat', {'cat': 0, 'ben': 1000}, squad: 'apt'),
      ];
      expect(simplifyDebts({'ann': -1000, 'ben': 0, 'cat': 1000}), [
        const SettlementItem(from: 'ann', to: 'cat', amountCents: 1000),
      ]);
      final raw = balances(me: 'ann', expenses: expenses, settlements: []);
      expect(raw, {'ben': -1000});
      final simple = balances(
        me: 'ann',
        expenses: expenses,
        settlements: [],
        simplified: {'apt'},
      );
      expect(simple, {'cat': -1000});
      expect(
        balances(
          me: 'ben',
          expenses: expenses,
          settlements: [],
          simplified: {'apt'},
        ),
        isEmpty,
      );
      // Ann pays Cat: everyone's square, simplified or not.
      final settled = [paid('ann', 'cat', 1000, squad: 'apt')];
      for (final who in ['ann', 'ben', 'cat']) {
        expect(
          balances(
            me: who,
            expenses: expenses,
            settlements: settled,
            simplified: {'apt'},
          ),
          isEmpty,
          reason: who,
        );
      }
    });

    test('a squad split and a one-on-one split add up per friend', () {
      final byScope = balancesByScope(
        me: 'me',
        expenses: [
          split('me', {'me': 1000, 'ann': 1000}, squad: 'apt'),
          split('ann', {'ann': 300, 'me': 300}),
        ],
        settlements: const [],
      );
      expect(byScope, {
        'ann': {'apt': 1000, null: -300},
      });
    });
  });

  group('settleUp', () {
    test('settling everything clears every scope, both directions', () {
      final items = settleUp(
        me: 'me',
        friend: 'ann',
        byScope: {'apt': 1000, null: -300},
      );
      expect(
        items,
        unorderedEquals([
          const SettlementItem(
            squadId: 'apt',
            from: 'ann',
            to: 'me',
            amountCents: 1000,
          ),
          const SettlementItem(from: 'me', to: 'ann', amountCents: 300),
        ]),
      );
    });

    test('a partial payment goes to the biggest debt first', () {
      final items = settleUp(
        me: 'me',
        friend: 'ann',
        byScope: {'apt': 1000, 'trip': 400},
        amountCents: 1200,
      );
      expect(items, [
        const SettlementItem(
          squadId: 'apt',
          from: 'ann',
          to: 'me',
          amountCents: 1000,
        ),
        const SettlementItem(
          squadId: 'trip',
          from: 'ann',
          to: 'me',
          amountCents: 200,
        ),
      ]);
    });

    test('never records more than is owed', () {
      final items = settleUp(
        me: 'me',
        friend: 'ann',
        byScope: {null: -500},
        amountCents: 9999,
      );
      expect(items, [
        const SettlementItem(from: 'me', to: 'ann', amountCents: 500),
      ]);
    });
  });
}
