/// "Can I afford it?" coach. The UI only talks to [AffordabilityCoach], so the
/// local rules below can later be swapped for (or wrapped by) a Gemini-backed
/// coach that receives [CoachGrounding] as context.
library;

import 'dart:math' as math;

import 'budget_math.dart';
import 'format.dart';
import 'models.dart';

enum Verdict { yes, trade, no }

/// The numbers a coach is allowed to reason with. Also the JSON grounding we
/// will hand to an LLM so it can't invent figures.
class CoachGrounding {
  const CoachGrounding({
    required this.available,
    required this.safeToSpendToday,
    required this.dailyAllowance,
    required this.spentToday,
    required this.daysLeft,
    required this.burnRate,
    required this.daysShort,
    this.period = BudgetPeriod.semester,
  });

  factory CoachGrounding.fromSnapshot(
    RunwaySnapshot s, {
    BudgetPeriod period = BudgetPeriod.semester,
  }) => CoachGrounding(
    available: s.available,
    safeToSpendToday: s.safeToSpendToday,
    dailyAllowance: s.dailyAllowance,
    spentToday: s.spentToday,
    daysLeft: s.daysLeft,
    burnRate: s.burnRate,
    daysShort: s.daysShort,
    period: period,
  );

  final double available;
  final double safeToSpendToday;
  final double dailyAllowance;
  final double spentToday;
  final int daysLeft;
  final double burnRate;
  final int daysShort;

  /// What [daysLeft] counts down to: the end of the semester or the month.
  final BudgetPeriod period;

  Map<String, Object> toJson() => {
    'period': period.noun,
    'available': available,
    'safeToSpendToday': safeToSpendToday,
    'dailyAllowance': dailyAllowance,
    'spentToday': spentToday,
    'daysLeftInTerm': daysLeft,
    'burnRatePerDay': burnRate,
    'daysShort': daysShort,
  };
}

class Assessment {
  const Assessment({
    required this.verdict,
    required this.item,
    required this.amount,
    required this.dailyBefore,
    required this.dailyAfter,
    required this.runwayDaysLost,
    required this.message,
    this.period = BudgetPeriod.semester,
  });

  final Verdict verdict;
  final String item;
  final double amount;
  final double dailyBefore;
  final double dailyAfter;
  final double runwayDaysLost;
  final String message;
  final BudgetPeriod period;

  String get headline => switch (verdict) {
    Verdict.yes => 'Yes',
    Verdict.trade => 'Yes, if you trade for it',
    Verdict.no => switch (period) {
      BudgetPeriod.semester => 'Not this term',
      BudgetPeriod.monthly => 'Not this month',
    },
  };
}

/// A coach reply: either an assessment card or plain text.
class CoachReply {
  const CoachReply.text(this.text) : assessment = null;
  const CoachReply.assessment(Assessment this.assessment) : text = null;
  final String? text;
  final Assessment? assessment;
}

abstract interface class AffordabilityCoach {
  Future<CoachReply> ask(String question, CoachGrounding grounding);
}

/// Share of `available` you can afford by trading away other spending.
const tradeThreshold = 0.12;

/// Price of the "skip N delivery orders" trade unit.
final double deliveryOrderCost = ExpensePreset.all
    .firstWhere((p) => p.category == ExpenseCategory.delivery)
    .amount;

final _dollarAmount = RegExp(r'\$\s*(\d[\d,]*(?:\.\d{1,2})?)');
final _bareAmount = RegExp(r'(\d[\d,]*(?:\.\d{1,2})?)');

/// Pulls the first money amount out of free text. Prefers `$`-prefixed numbers.
({double amount, String item})? parseQuestion(String text) {
  final match = _dollarAmount.firstMatch(text) ?? _bareAmount.firstMatch(text);
  if (match == null) return null;
  final amount = double.tryParse(match.group(1)!.replaceAll(',', ''));
  if (amount == null || amount <= 0) return null;
  var item = text.replaceRange(match.start, match.end, ' ');
  item = item
      .replaceAll(RegExp(r'[?!.]'), ' ')
      .replaceAll(
        RegExp(
          r'\b(can|could|i|afford|it|a|an|the|for|buy|get|should)\b',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return (amount: amount, item: item.isEmpty ? 'that' : item);
}

Assessment assess(double amount, String item, CoachGrounding g) {
  final dailyBefore = g.dailyAllowance;
  final dailyAfter = (g.available - amount + g.spentToday) / g.daysLeft;
  final daysLost = g.burnRate > 0 ? amount / g.burnRate : 0.0;

  if (amount <= g.safeToSpendToday) {
    return Assessment(
      period: g.period,
      verdict: Verdict.yes,
      item: item,
      amount: amount,
      dailyBefore: dailyBefore,
      // Fits inside today's allowance, so the daily number doesn't move.
      dailyAfter: dailyBefore,
      runwayDaysLost: 0,
      message:
          'Go for it — that fits inside today\'s safe-to-spend. '
          'You\'ll still have ${money(g.safeToSpendToday - amount)} left today.',
    );
  }

  if (amount <= g.available * tradeThreshold) {
    final orders = math.max(1, (amount / deliveryOrderCost).ceil());
    return Assessment(
      period: g.period,
      verdict: Verdict.trade,
      item: item,
      amount: amount,
      dailyBefore: dailyBefore,
      dailyAfter: dailyAfter,
      runwayDaysLost: daysLost,
      message:
          'Doable if you trade for it: skip ${plural(orders, 'delivery order')} '
          'and your runway stays where it is.',
    );
  }

  final perWeek = math.max(10.0, (g.dailyAllowance * 7 * 0.2).roundToDouble());
  final weeks = (amount / perWeek).ceil();
  return Assessment(
    period: g.period,
    verdict: Verdict.no,
    item: item,
    amount: amount,
    dailyBefore: dailyBefore,
    dailyAfter: dailyAfter,
    runwayDaysLost: daysLost,
    message:
        'That would eat ${(amount / math.max(1, g.available) * 100).round()}% '
        'of what you have left. Make it a goal: put ${money(perWeek, cents: false)}'
        '/week aside and you\'ll have it in ${plural(weeks, 'week')}.',
  );
}

/// Rule-based coach that runs entirely on-device.
class LocalCoach implements AffordabilityCoach {
  const LocalCoach();

  @override
  Future<CoachReply> ask(String question, CoachGrounding grounding) async {
    final parsed = parseQuestion(question);
    if (parsed == null) {
      return const CoachReply.text(
        'Tell me what it costs — like "Concert ticket \$60" — and I\'ll run '
        'it against your runway.',
      );
    }
    return CoachReply.assessment(assess(parsed.amount, parsed.item, grounding));
  }
}
