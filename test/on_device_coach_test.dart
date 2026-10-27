import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/coach.dart';
import 'package:runway/app/models.dart';
import 'package:runway/app/on_device_coach.dart';
import 'package:runway/app/spending_lookup.dart';
import 'package:runway/app/week_recap.dart';

class _FakeModel implements CoachModel {
  _FakeModel(this.reply, {this.lookUpWith});
  final FutureOr<String?> Function() reply;

  /// Arguments to call the lookup with before replying, like the real
  /// model calling lookUpSpending.
  final Map<String, Object?>? lookUpWith;
  String? lastPrompt;
  String? lastInstructions;
  bool offeredLookUp = false;
  Map<String, Object>? lookedUp;

  @override
  Future<String?> respond({
    required String instructions,
    required String prompt,
    SpendingLookUp? lookUp,
  }) async {
    lastPrompt = prompt;
    lastInstructions = instructions;
    offeredLookUp = lookUp != null;
    if (lookUpWith case final args? when lookUp != null) {
      lookedUp = lookUp(args);
    }
    return reply();
  }
}

void main() {
  // Same numbers as coach_test.dart: safe today $20, trade ceiling $120.
  const g = CoachGrounding(
    available: 1000,
    safeToSpendToday: 20,
    dailyAllowance: 25,
    spentToday: 5,
    daysLeft: 40,
    burnRate: 30,
    daysShort: 0,
    byCategory: [(category: 'Food', spent: 212.5)],
  );

  test(
    'keeps the local verdict and numbers, with the model\'s words',
    () async {
      final model = _FakeModel(
        () => 'Totally fine, boba fits in today and you keep \$14 for later.',
      );
      final reply = await OnDeviceCoach(model).ask('Boba \$6', g);
      final a = reply.assessment!;
      expect(a.verdict, Verdict.yes);
      expect(a.amount, 6);
      expect(a.dailyAfter, 25);
      expect(a.message, startsWith('Totally fine'));
      expect(model.lastPrompt, contains('"Yes"'));
      expect(model.lastPrompt, contains('"price":6.0'));
    },
  );

  test('answers open questions from the facts', () async {
    final model = _FakeModel(
      () => 'Food is your biggest spend so far at \$212.50.',
    );
    final reply = await OnDeviceCoach(model).ask('How am I doing on food?', g);
    expect(reply.text, 'Food is your biggest spend so far at \$212.50.');
    expect(model.lastPrompt, contains('"Food":212.5'));
  });

  test('asks for the price instead of letting the model guess', () async {
    final model = _FakeModel(() => 'Yes, you can afford it!');
    final reply = await OnDeviceCoach(model)
        .ask('can i afford a dior wallet', g);
    expect(reply.assessment, isNull);
    expect(reply.text, startsWith('How much is the dior wallet?'));
    expect(model.lastPrompt, isNull);
  });

  test('throws away a yes or no about affording with no purchase', () async {
    final model = _FakeModel(() => 'You can afford a little treat this week.');
    final reply = await OnDeviceCoach(model).ask('How is my week going?', g);
    expect(reply.text, contains('Tell me what it costs'));
  });

  test('throws away a reply with a dollar amount it wasn\'t given', () async {
    final model = _FakeModel(() => 'Sure! You will still have \$480 left.');
    final reply = await OnDeviceCoach(model).ask('Boba \$6', g);
    expect(reply.assessment!.message, startsWith('Go for it'));
  });

  test('falls back to the rule-based coach when unavailable', () async {
    final reply = await OnDeviceCoach(_FakeModel(() => null)).ask('hmm', g);
    expect(reply.text, contains('Tell me what it costs'));
  });

  test('falls back when the model is too slow', () async {
    final never = Completer<String?>().future;
    final coach = OnDeviceCoach(
      _FakeModel(() => never),
      timeout: const Duration(milliseconds: 10),
    );
    final reply = await coach.ask('AirPods \$129', g);
    expect(reply.assessment!.verdict, Verdict.no);
    expect(reply.assessment!.message, startsWith('That would eat'));
  });

  group('onlyKnownAmounts', () {
    const facts = <String, Object>{
      'available': 1000.0,
      'purchase': {'suggestion': 'Put \$35/week aside.'},
    };

    test('allows amounts from the facts, rounded to the dollar', () {
      expect(onlyKnownAmounts('You have \$1,000.40 left.', facts), isTrue);
      expect(onlyKnownAmounts('Save \$35 a week.', facts), isTrue);
      expect(onlyKnownAmounts('No money mentioned.', facts), isTrue);
    });

    test('allows amounts the person typed', () {
      expect(
        onlyKnownAmounts('A \$60 ticket?', facts, question: 'ticket 60'),
        isTrue,
      );
    });

    test('rejects made-up amounts', () {
      expect(onlyKnownAmounts('You\'ll have \$940 left.', facts), isFalse);
    });
  });

  group('looking things up', () {
    final today = DateTime(2026, 10, 27, 15); // a Tuesday
    Expense spend(double amount, String note, DateTime date) => Expense(
      id: '$note$amount',
      amount: amount,
      category: ExpenseCategory.coffee,
      isNeed: false,
      date: date,
      note: note,
    );
    final expenses = [
      spend(5.25, 'Latte', DateTime(2026, 10, 19, 9)),
      spend(6.10, 'Cold brew', DateTime(2026, 10, 22, 9)),
    ];
    final history = SpendingHistory(
      expenses: expenses,
      ledger: const [],
      today: today,
      termStart: DateTime(2026, 9, 1),
    );
    final withHistory = CoachGrounding(
      available: 1000,
      safeToSpendToday: 20,
      dailyAllowance: 25,
      spentToday: 5,
      daysLeft: 40,
      burnRate: 30,
      daysShort: 0,
      history: history,
    );

    test('the model can look up last week and quote what it found', () async {
      final model = _FakeModel(
        () => 'You spent \$11.35 on coffee last week, mostly a cold brew.',
        lookUpWith: {'period': 'lastWeek', 'category': 'coffee'},
      );
      final reply = await OnDeviceCoach(model)
          .ask('How much coffee did I buy last week?', withHistory);
      expect(model.offeredLookUp, isTrue);
      expect(model.lastInstructions, contains('lookUpSpending'));
      expect(model.lastPrompt, contains('Tuesday, Oct 27, 2026'));
      expect(model.lookedUp!['spent'], 11.35);
      expect(reply.text, startsWith('You spent \$11.35'));
      expect(reply.fromModel, isTrue);
    });

    test('an amount it neither had nor looked up is thrown away', () async {
      final model = _FakeModel(
        () => 'You spent \$73 on coffee last week.',
        lookUpWith: {'period': 'lastWeek', 'category': 'coffee'},
      );
      final reply = await OnDeviceCoach(model)
          .ask('How much did I spend on coffee last week?', withHistory);
      expect(reply.fromModel, isFalse);
      expect(reply.text, startsWith('You spent \$11.35 on coffee last week'));
    });

    test('a purchase decision doesn\'t offer lookups', () async {
      final model = _FakeModel(() => 'Boba fits in today.');
      final reply = await OnDeviceCoach(model).ask('Boba \$6', withHistory);
      expect(model.offeredLookUp, isFalse);
      expect(reply.fromModel, isTrue);
    });
  });

  group('weekly recap', () {
    final week = WeekRecap(
      start: DateTime(2026, 10, 18),
      end: DateTime(2026, 10, 24),
      days: 7,
      spent: 142.3,
      budget: 180,
      daysUnder: 5,
      noSpendDays: 1,
      topCategory: (name: 'Eating out', spent: 58.2),
    );

    test('the model writes it from the week\'s facts', () async {
      final model = _FakeModel(
        () => 'Solid week: \$142.30 of \$180, and eating out led at \$58.20.',
      );
      final reply = await OnDeviceCoach(model).describeWeek(week);
      expect(reply.fromModel, isTrue);
      expect(reply.text, startsWith('Solid week'));
      expect(model.lastPrompt, contains('"underBudgetBy":37.7'));
    });

    test('made-up amounts fall back to the rules\' words', () async {
      final model = _FakeModel(() => 'You saved \$500 last week!');
      final reply = await OnDeviceCoach(model).describeWeek(week);
      expect(reply.fromModel, isFalse);
      expect(reply.text, week.summary);
    });
  });
}
