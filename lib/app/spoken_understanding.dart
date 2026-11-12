/// Gemini Nano reads what was said into the Quick Add mic, on Android
/// phones that have it: "grabbed a twelve dollar burrito at Chipotle" →
/// $12, Burrito at Chipotle, Eating out. The rules in spoken_expense.dart
/// fill the sheet first and stay whenever the model is missing, slow or
/// unsure. (On iPhone,
/// Siri's own logging does this in ios/Runner/VoiceLog.swift.)
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'on_device_coach.dart';
import 'spoken_expense.dart';

/// What the model made of a sentence. Any part can be missing.
class UnderstoodSpend {
  const UnderstoodSpend({this.amount, this.note, this.category});

  final double? amount;
  final String? note;
  final CategoryRef? category;
}

class SpokenUnderstanding {
  const SpokenUnderstanding(
    this.model, {
    this.timeout = const Duration(seconds: 6),
  });

  final CoachModel model;
  final Duration timeout;

  /// Android only: on iPhone the mic keeps the rules, and Siri has its own.
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const instructions =
      'You read one sentence a college student said to log money they '
      'spent, and pull out the details. Reply with only a JSON object, no '
      'other text: {"amount": number or null, "item": string, "category": '
      'string, "ownCategory": string or null}. "amount" is only what they '
      'paid themselves: for a shared or split bill, just their share. Never '
      'guess an amount that wasn\'t said; use null. "item" is what it was or '
      'where, in 1 to 4 words, like "Chipotle" or "Uber to the airport", '
      'with no amount and no words like "spent" or "paid". "category" is '
      'one of: coffee, groceries, eatingOut, lateNight, delivery, rideshare, '
      'transit, supplies, travel, shopping, fun, bills, other.';

  /// Null when the model isn't there, is slow, or replies with nothing
  /// usable.
  Future<UnderstoodSpend?> read(
    String said, {
    List<CustomCategory> customs = const [],
  }) async {
    final own = customs.isEmpty
        ? 'They have no categories of their own.'
        : 'Their own categories are: '
              '${customs.map((c) => c.name).join(', ')}. Put one in '
              '"ownCategory" only if it clearly fits.';
    final String? reply;
    try {
      reply = await model
          .respond(
            instructions: '$instructions $own',
            prompt: said,
            temperature: 0,
          )
          .timeout(timeout);
    } on TimeoutException {
      return null;
    }
    return parseUnderstanding(reply, said: said, customs: customs);
  }
}

final _number = RegExp(r'\d[\d,]*(?:\.\d+)?');

/// The model's JSON [reply] as an [UnderstoodSpend], checked against what
/// was actually [said]: its amount is kept only if that number was said
/// (in digits, or in words the rules understood), so it can never make one
/// up. Null if there's nothing usable.
@visibleForTesting
UnderstoodSpend? parseUnderstanding(
  String? reply, {
  required String said,
  List<CustomCategory> customs = const [],
}) {
  if (reply == null) return null;
  final start = reply.indexOf('{');
  final end = reply.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(reply.substring(start, end + 1));
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, Object?>) return null;

  final saidNumbers = [
    for (final m in _number.allMatches(said))
      double.parse(m.group(0)!.replaceAll(',', '')),
    ?SpokenExpense.parse(said).amount,
  ];
  final amount = switch (decoded['amount']) {
    final num n
        when n > 0 &&
            n < 100000 &&
            saidNumbers.any((s) => (s - n).abs() < 0.005) =>
      n.toDouble(),
    _ => null,
  };

  final note = switch (decoded['item']) {
    final String s when s.trim().isNotEmpty && !s.contains(_number) =>
      _capitalized(s.trim().replaceAll(RegExp(r'\s+'), ' ')),
    _ => null,
  };

  CategoryRef? category;
  if (decoded['ownCategory'] case final String name) {
    for (final c in customs) {
      if (c.name.toLowerCase() == name.trim().toLowerCase()) {
        category = CategoryRef(ExpenseCategory.other, c);
      }
    }
  }
  if (category == null) {
    if (decoded['category'] case final String name) {
      final c = ExpenseCategory.values.asNameMap()[name.trim()];
      if (c != null && c != ExpenseCategory.other) category = CategoryRef(c);
    }
  }

  if (amount == null && note == null && category == null) return null;
  return UnderstoodSpend(
    amount: amount,
    note: note == null || note.length > 40 ? null : note,
    category: category,
  );
}

String _capitalized(String s) => s[0].toUpperCase() + s.substring(1);
