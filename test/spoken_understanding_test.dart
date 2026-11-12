import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/models.dart';
import 'package:runway/app/on_device_coach.dart';
import 'package:runway/app/spoken_understanding.dart';

class _FakeModel implements CoachModel {
  _FakeModel(this.reply);
  final FutureOr<String?> Function() reply;

  String? lastInstructions;
  String? lastPrompt;
  double? lastTemperature;

  @override
  bool get canLookUp => false;

  @override
  Future<String?> respond({
    required String instructions,
    required String prompt,
    SpendingLookUp? lookUp,
    double? temperature,
  }) async {
    lastInstructions = instructions;
    lastPrompt = prompt;
    lastTemperature = temperature;
    return reply();
  }
}

const _gym = CustomCategory(id: 'g', emoji: '🏋️', name: 'Gym');

void main() {
  group('Reading the model\'s reply', () {
    test('takes the amount, item and category', () {
      final read = parseUnderstanding(
        '{"amount": 12, "item": "burrito at Chipotle", '
        '"category": "eatingOut", "ownCategory": null}',
        said: 'grabbed a 12 dollar burrito at Chipotle',
      )!;
      expect(read.amount, 12);
      expect(read.note, 'Burrito at Chipotle');
      expect(read.category, const CategoryRef(ExpenseCategory.eatingOut));
    });

    test('finds the JSON inside extra words or a code fence', () {
      final read = parseUnderstanding(
        'Sure!\n```json\n{"amount": 8, "item": "coffee", '
        '"category": "coffee"}\n```',
        said: '8 bucks on coffee',
      )!;
      expect(read.amount, 8);
      expect(read.category, const CategoryRef(ExpenseCategory.coffee));
    });

    test('keeps an amount said in words', () {
      final read = parseUnderstanding(
        '{"amount": 45, "item": "shoes", "category": "shopping"}',
        said: 'forty five bucks on shoes',
      )!;
      expect(read.amount, 45);
    });

    test('keeps a share of a split bill only if that number was said', () {
      final made = parseUnderstanding(
        '{"amount": 20, "item": "dinner", "category": "eatingOut"}',
        said: 'split a 60 dollar dinner three ways',
      )!;
      expect(made.amount, isNull);
      expect(made.note, 'Dinner');

      final said = parseUnderstanding(
        '{"amount": 20, "item": "dinner", "category": "eatingOut"}',
        said: 'my share of dinner was 20',
      )!;
      expect(said.amount, 20);
    });

    test('never keeps an amount that wasn\'t said', () {
      final read = parseUnderstanding(
        '{"amount": 5, "item": "coffee", "category": "coffee"}',
        said: 'coffee with Sam',
      )!;
      expect(read.amount, isNull);
      expect(read.note, 'Coffee');
    });

    test('drops an item with a number in it or one that runs long', () {
      expect(
        parseUnderstanding(
          '{"amount": 12, "item": "12 dollars lunch", "category": "other"}',
          said: '12 dollars lunch',
        )!.note,
        isNull,
      );
      expect(
        parseUnderstanding(
          '{"amount": 12, "item": "${'very ' * 10}long lunch"}',
          said: '12 dollars lunch',
        )!.note,
        isNull,
      );
    });

    test('ignores "other" and categories that don\'t exist', () {
      expect(
        parseUnderstanding(
          '{"amount": 3, "item": "gum", "category": "other"}',
          said: '3 dollars gum',
        )!.category,
        isNull,
      );
      expect(
        parseUnderstanding(
          '{"amount": 3, "item": "gum", "category": "candy"}',
          said: '3 dollars gum',
        )!.category,
        isNull,
      );
    });

    test('uses one of their own categories when it names one', () {
      final read = parseUnderstanding(
        '{"amount": 30, "item": "day pass", "category": "fun", '
        '"ownCategory": "gym"}',
        said: '30 for a gym day pass',
        customs: const [_gym],
      )!;
      expect(read.category, const CategoryRef(ExpenseCategory.other, _gym));
    });

    test('falls back to a built-in category for an unknown own one', () {
      final read = parseUnderstanding(
        '{"amount": 30, "item": "day pass", "category": "fun", '
        '"ownCategory": "Climbing"}',
        said: '30 for a day pass',
        customs: const [_gym],
      )!;
      expect(read.category, const CategoryRef(ExpenseCategory.fun));
    });

    test('is null for nothing, junk, or nothing usable', () {
      expect(parseUnderstanding(null, said: 'x'), isNull);
      expect(parseUnderstanding('no idea', said: 'x'), isNull);
      expect(parseUnderstanding('{"amount": ', said: 'x'), isNull);
      expect(parseUnderstanding('[1, 2]', said: '1 2'), isNull);
      expect(
        parseUnderstanding(
          '{"amount": null, "item": "", "category": "other"}',
          said: 'hmm',
        ),
        isNull,
      );
    });
  });

  group('Asking the model', () {
    test(
      'sends what was said, at temperature 0, with their categories',
      () async {
        final model = _FakeModel(
          () => '{"amount": 8, "item": "coffee", "category": "coffee"}',
        );
        final read = await SpokenUnderstanding(model)
            .read('8 bucks on coffee', customs: const [_gym]);
        expect(read!.amount, 8);
        expect(model.lastPrompt, '8 bucks on coffee');
        expect(model.lastTemperature, 0);
        expect(model.lastInstructions, contains('Gym'));
      },
    );

    test('says when they have no categories of their own', () async {
      final model = _FakeModel(() => null);
      await SpokenUnderstanding(model).read('8 bucks on coffee');
      expect(model.lastInstructions, contains('no categories of their own'));
    });

    test('gives up when the model is slow', () async {
      final model = _FakeModel(
        () => Future.delayed(
          const Duration(seconds: 1),
          () => '{"amount": 8, "item": "coffee"}',
        ),
      );
      final read = await SpokenUnderstanding(
        model,
        timeout: const Duration(milliseconds: 10),
      ).read('8 bucks on coffee');
      expect(read, isNull);
    });

    test('is null when the model isn\'t there', () async {
      final read = await SpokenUnderstanding(_FakeModel(() => null))
          .read('8 bucks on coffee');
      expect(read, isNull);
    });
  });
}
