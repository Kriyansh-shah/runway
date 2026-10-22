import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/coach.dart';
import 'package:runway/app/on_device_coach.dart';

class _FakeModel implements CoachModel {
  _FakeModel(this.reply);
  final FutureOr<String?> Function() reply;
  String? lastPrompt;

  @override
  Future<String?> respond({
    required String instructions,
    required String prompt,
  }) async {
    lastPrompt = prompt;
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
}
