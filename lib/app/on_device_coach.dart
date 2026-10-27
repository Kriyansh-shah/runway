/// The coach with Apple's on-device model (iOS 26, Apple Intelligence).
/// The rules in coach.dart still make every decision and every number; the
/// model only puts them into words and answers questions about the person's
/// own figures, looking up past spending through [SpendingHistory] when it
/// needs to. It also writes the weekly recap. Nothing leaves the phone. Whenever the model is unavailable,
/// slow, or says a dollar amount it wasn't given, the rule-based reply is
/// shown instead.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'coach.dart';
import 'format.dart';
import 'spending_lookup.dart';
import 'week_recap.dart';

/// Answers the model's "lookUpSpending" calls with facts, from
/// [SpendingHistory.lookUp]'s arguments.
typedef SpendingLookUp = Map<String, Object> Function(
  Map<String, Object?> arguments,
);

/// A language model that turns facts into a short reply. Null when it's
/// unavailable or fails. With [lookUp], the model can ask for past
/// spending while it answers.
abstract interface class CoachModel {
  Future<String?> respond({
    required String instructions,
    required String prompt,
    SpendingLookUp? lookUp,
  });
}

/// Apple's on-device model through ios/Runner/CoachModel.swift.
class AppleCoachModel implements CoachModel {
  const AppleCoachModel();

  static const _channel = MethodChannel('runway/coach');

  /// Only the iPhone app has it; the web and Android don't.
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// "available", or why not; see CoachModel.swift.
  static Future<String> status() async {
    try {
      return await _channel.invokeMethod<String>('status') ?? 'unsupported';
    } on Object {
      return 'unsupported';
    }
  }

  /// The lookup for the question being answered; the Swift side calls
  /// back through [_channel] while the model works.
  static SpendingLookUp? _lookUp;
  static var _listening = false;

  static Future<Object?> _handle(MethodCall call) async {
    if (call.method != 'lookUp') throw MissingPluginException();
    final lookUp = _lookUp;
    if (lookUp == null) return jsonEncode({'error': 'Nothing to look up.'});
    final args = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
    return jsonEncode(lookUp(args));
  }

  @override
  Future<String?> respond({
    required String instructions,
    required String prompt,
    SpendingLookUp? lookUp,
  }) async {
    // Checked every time: Apple Intelligence can be switched on, or finish
    // downloading, while the app is open.
    if (await status() != 'available') return null;
    if (!_listening) {
      _channel.setMethodCallHandler(_handle);
      _listening = true;
    }
    if (lookUp != null) _lookUp = lookUp;
    try {
      return await _channel.invokeMethod<String>('respond', {
        'instructions': instructions,
        'prompt': prompt,
        'tools': lookUp != null,
      });
    } on PlatformException catch (e) {
      debugPrint('On-device coach failed: ${e.message}');
      return null;
    } finally {
      if (lookUp != null && identical(_lookUp, lookUp)) _lookUp = null;
    }
  }
}

class OnDeviceCoach implements AffordabilityCoach {
  const OnDeviceCoach(
    this.model, {
    this.fallback = const LocalCoach(),
    this.timeout = const Duration(seconds: 12),
    this.lookUpTimeout = const Duration(seconds: 20),
  });

  final CoachModel model;
  final LocalCoach fallback;
  final Duration timeout;

  /// Longer when the model may look things up: that's a second pass.
  final Duration lookUpTimeout;

  static const instructions =
      'You are the money coach in Runway, a budgeting app for college '
      'students. Reply in one to three short, friendly sentences of plain '
      'text: no lists, no headings, no emoji. Speak to the student as "you". '
      'Use only the dollar amounts given in the facts, written the way they '
      'are given; never work out or estimate new ones. Never say whether '
      'the student can or can\'t afford something unless the facts include '
      'a purchase with a decision; without one, ask for the price. If the '
      'facts can\'t answer the question, say so kindly and suggest asking '
      '"Can I afford <item> \$<price>?". Don\'t give investment, loan, '
      'credit or tax advice.';

  /// Added when the model can look up past spending.
  static const lookUpInstructions =
      ' For questions about past spending, like a day, a week, a month or '
      'a category, call lookUpSpending first and answer from what it '
      'returns, using its amounts exactly. "Today" in the facts tells you '
      'the date.';

  static const weekInstructions =
      'You are the money coach in Runway, a budgeting app for college '
      'students. Write a short recap of the student\'s last week in two or '
      'three friendly sentences of plain text: no lists, no headings, no '
      'emoji. Speak to the student as "you". Say how the week went against '
      'the budget and point out one thing worth noticing. Use only the '
      'dollar amounts given in the facts, written the way they are given; '
      'never work out or estimate new ones. Don\'t give investment, loan, '
      'credit or tax advice.';

  @override
  Future<CoachReply> ask(String question, CoachGrounding grounding) async {
    final local = await fallback.ask(question, grounding);
    // A purchase with no price: ask for it. The model can't know what a
    // Dior wallet costs, and guessing would mean a made-up yes or no.
    if (purchaseWithoutPrice(question) != null) return local;
    final assessment = local.assessment;
    final history = assessment == null ? grounding.history : null;
    final facts = {
      ..._facts(grounding, assessment),
      if (history != null)
        'today':
            '${weekdayName(history.today)}, ${shortDate(history.today)}, '
            '${history.today.year}',
    };
    // What the model looked up counts as given, for the amounts check.
    final lookedUp = <Map<String, Object>>[];
    Map<String, Object> lookUp(Map<String, Object?> args) {
      final found = history!.lookUp(
        period: args['period'] as String? ?? '',
        day: args['day'] as String?,
        category: args['category'] as String?,
      );
      lookedUp.add(found);
      return found;
    }

    final prompt = assessment == null
        ? 'Facts about my budget:\n${jsonEncode(facts)}\n\n'
              'My question: $question'
        : 'Facts about my budget and this purchase:\n${jsonEncode(facts)}\n\n'
              'The decision is already made: "${assessment.headline}". '
              'In your own words, tell me that and why, and give me the '
              'suggestion. If there\'s a savings plan, tell me how much to '
              'put aside and how long until I can buy it, using its numbers '
              'and "readyIn" exactly. My question was: $question';
    final String? reply;
    try {
      reply = await model
          .respond(
            instructions: history == null
                ? instructions
                : instructions + lookUpInstructions,
            prompt: prompt,
            lookUp: history == null ? null : lookUp,
          )
          .timeout(history == null ? timeout : lookUpTimeout);
    } on TimeoutException {
      return local;
    }
    final text = reply?.trim() ?? '';
    final known = {...facts, 'lookedUp': lookedUp};
    if (text.isEmpty || !onlyKnownAmounts(text, known, question: question)) {
      return local;
    }
    // Belt and braces: with no purchase decided, a reply about affording
    // something is the model guessing.
    if (assessment == null && _affordVerdict.hasMatch(text)) return local;
    if (assessment == null) return CoachReply.text(text, fromModel: true);
    return CoachReply.assessment(
      Assessment(
        verdict: assessment.verdict,
        item: assessment.item,
        amount: assessment.amount,
        dailyBefore: assessment.dailyBefore,
        dailyAfter: assessment.dailyAfter,
        runwayDaysLost: assessment.runwayDaysLost,
        message: text,
        period: assessment.period,
        plan: assessment.plan,
        fasterPlan: assessment.fasterPlan,
      ),
      fromModel: true,
    );
  }

  @override
  Future<CoachReply> describeWeek(WeekRecap week) async {
    final local = await fallback.describeWeek(week);
    final facts = week.toFacts();
    final String? reply;
    try {
      reply = await model
          .respond(
            instructions: weekInstructions,
            prompt: 'Facts about my last week:\n${jsonEncode(facts)}',
          )
          .timeout(timeout);
    } on TimeoutException {
      return local;
    }
    final text = reply?.trim() ?? '';
    if (text.isEmpty || !onlyKnownAmounts(text, facts)) return local;
    return CoachReply.text(text, fromModel: true);
  }

  /// Rounded to cents, so the model sees amounts the way the app shows them.
  static Map<String, Object> _facts(CoachGrounding g, Assessment? a) {
    Object round(Object v) => switch (v) {
      final double d => double.parse(d.toStringAsFixed(2)),
      final Map<String, Object> m => {
        for (final MapEntry(:key, :value) in m.entries) key: round(value),
      },
      _ => v,
    };
    return {
      for (final MapEntry(:key, :value) in g.toJson().entries)
        key: round(value),
      if (a != null)
        'purchase': {
          'item': a.item,
          'price': round(a.amount),
          'verdict': a.headline,
          'dailyAllowanceNow': round(a.dailyBefore),
          'dailyAllowanceAfter': round(a.dailyAfter),
          'daysOfRunwayLost': round(a.runwayDaysLost),
          if (a.plan case final p?)
            'savingsPlan': {
              'putAsidePerDay': round(p.perDay),
              'putAsidePerWeek': round(p.perWeek),
              'readyIn': p.howLong,
              'readyBeforeThe${g.period.noun}Ends': p.days <= g.daysLeft,
              if (a.fasterPlan case final f?) ...{
                'fasterPerDay': round(f.perDay),
                'fasterReadyIn': f.howLong,
              },
            },
          'suggestion': a.message,
        },
    };
  }
}

final _affordVerdict = RegExp(
  r"\b(can|can't|cannot|could|couldn't|able to) (still )?afford|go for it",
  caseSensitive: false,
);

final _replyAmount = RegExp(r'\$\s*(\d[\d,]*(?:\.\d+)?)');
final _factNumber = RegExp(r'\d[\d,]*(?:\.\d+)?');

/// Whether every dollar amount in [reply] is one of the [facts] or was in
/// the [question] (to the nearest dollar, since the model may round). A
/// reply with an amount the coach didn't give it is thrown away.
@visibleForTesting
bool onlyKnownAmounts(
  String reply,
  Map<String, Object> facts, {
  String question = '',
}) {
  final known = <double>[];
  void collect(Object? v) {
    switch (v) {
      case final num n:
        known.add(n.toDouble().abs());
      case final String s:
        for (final m in _factNumber.allMatches(s)) {
          known.add(double.parse(m.group(0)!.replaceAll(',', '')));
        }
      case final Map<String, Object> m:
        m.values.forEach(collect);
      case final List<Object?> l:
        l.forEach(collect);
    }
  }

  collect(facts);
  collect(question);
  for (final m in _replyAmount.allMatches(reply)) {
    final amount = double.parse(m.group(1)!.replaceAll(',', ''));
    if (!known.any((k) => (k - amount).abs() < 1)) return false;
  }
  return true;
}
