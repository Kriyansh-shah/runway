/// "Can I afford it?" coach. The UI only talks to [AffordabilityCoach]: the
/// local rules below run everywhere, and on iPhones with Apple Intelligence
/// [OnDeviceCoach] (on_device_coach.dart) puts them into words.
library;

import 'dart:math' as math;

import 'budget_math.dart';
import 'format.dart';
import 'models.dart';
import 'spending_lookup.dart';
import 'week_recap.dart';

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
    this.savingsGoal = 0,
    this.reserved = 0,
    this.spentSoFar = 0,
    this.byCategory = const [],
    this.savingFor = const [],
    this.putAsideToday = 0,
    this.history,
  });

  factory CoachGrounding.fromSnapshot(
    RunwaySnapshot s, {
    BudgetPeriod period = BudgetPeriod.semester,
    List<({String category, double spent})> byCategory = const [],
    List<({String name, double saved, double target})> savingFor = const [],
    SpendingHistory? history,
  }) => CoachGrounding(
    available: s.available,
    safeToSpendToday: s.safeToSpendToday,
    dailyAllowance: s.dailyAllowance,
    spentToday: s.spentToday,
    daysLeft: s.daysLeft,
    burnRate: s.burnRate,
    daysShort: s.daysShort,
    period: period,
    savingsGoal: s.savingsGoal,
    reserved: s.reserved,
    spentSoFar: s.everydaySpent,
    byCategory: byCategory,
    savingFor: savingFor,
    putAsideToday: s.putInJarsToday,
    history: history,
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

  /// Set aside for savings this term, like [reserved].
  final double savingsGoal;

  /// Upcoming bills and costs still to pay, already taken out of [available].
  final double reserved;

  /// Day-to-day spending this term so far.
  final double spentSoFar;

  /// This term's spending per category, biggest first.
  final List<({String category, double spent})> byCategory;

  /// Put into savings jars today; comes out of today's money like
  /// [spentToday].
  final double putAsideToday;

  /// Things being saved up for, apart from the savings goal.
  final List<({String name, double saved, double target})> savingFor;

  /// Past spending the on-device model can look things up in. Not part of
  /// [toJson]: it's asked for a piece at a time.
  final SpendingHistory? history;

  Map<String, Object> toJson() => {
    'period': period.noun,
    'available': available,
    'safeToSpendToday': safeToSpendToday,
    'dailyAllowance': dailyAllowance,
    'spentToday': spentToday,
    'putAsideToday': putAsideToday,
    'daysLeftInTerm': daysLeft,
    'burnRatePerDay': burnRate,
    'daysShort': daysShort,
    'savingsGoal': savingsGoal,
    'setAsideForBills': reserved,
    'spentSoFarThisTerm': spentSoFar,
    'spentByCategory': {for (final c in byCategory) c.category: c.spent},
    'savingUpFor': {
      for (final j in savingFor)
        j.name: {'savedSoFar': j.saved, 'price': j.target},
    },
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
    this.plan,
    this.fasterPlan,
  });

  final Verdict verdict;
  final String item;
  final double amount;
  final double dailyBefore;
  final double dailyAfter;
  final double runwayDaysLost;
  final String message;
  final BudgetPeriod period;

  /// How to save up for it, when it's not affordable now.
  final SavingsPlan? plan;

  /// A quicker way, putting more aside each day. Null when it isn't
  /// meaningfully quicker.
  final SavingsPlan? fasterPlan;

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
  const CoachReply.text(this.text, {this.fromModel = false})
    : assessment = null;
  const CoachReply.assessment(
    Assessment this.assessment, {
    this.fromModel = false,
  }) : text = null;
  final String? text;
  final Assessment? assessment;

  /// Worded by Apple Intelligence rather than the rules, so the app can
  /// say so.
  final bool fromModel;
}

abstract interface class AffordabilityCoach {
  Future<CoachReply> ask(String question, CoachGrounding grounding);

  /// Last week in a few sentences, for the card on Home.
  Future<CoachReply> describeWeek(WeekRecap week);
}

/// Share of `available` you can afford by trading away other spending.
const tradeThreshold = 0.12;

/// Price of the "skip N delivery orders" trade unit.
final double deliveryOrderCost = ExpensePreset.all
    .firstWhere((p) => p.category == ExpenseCategory.delivery)
    .amount;

final _dollarAmount = RegExp(r'\$\s*(\d[\d,]*(?:\.\d{1,2})?)');

/// A number on its own, not part of a name like "PS5" or "Air Max 90s".
final _bareAmount = RegExp(
  r'(?<![A-Za-z\d])(\d[\d,]*(?:\.\d{1,2})?)(?![A-Za-z\d])',
);

/// Sums like "1+1" or "5 * 3": numbers that aren't a price.
final _arithmetic = RegExp(r'\d\s*[-+*/×÷^=]\s*\d');

/// Questions put to the coach ("Can you do 1+1?", "What's 12 times 4?")
/// rather than about something to buy.
final _askingTheCoach = RegExp(
  r"^\s*(what|what's|whats|how|why|who|when|where|which|can you|could you|"
  r'will you|would you|do you|are you|tell me|calculate|solve)\b',
  caseSensitive: false,
);

/// Pulls the first money amount out of free text. Prefers `$`-prefixed
/// numbers. A number without `$` only counts as a price when it reads like
/// one: not part of a sum, and not in a question to the coach unless it's
/// about buying something.
({double amount, String item})? parseQuestion(String text) {
  var match = _dollarAmount.firstMatch(text);
  if (match == null &&
      !_arithmetic.hasMatch(text) &&
      (!_askingTheCoach.hasMatch(text) || _purchaseWords.hasMatch(text))) {
    match = _bareAmount.firstMatch(text);
  }
  if (match == null) return null;
  final amount = double.tryParse(match.group(1)!.replaceAll(',', ''));
  // A billion dollars or more is a joke or a typo, not a purchase.
  if (amount == null || amount < 0.005 || amount >= 1e9) return null;
  final item = _itemName(text.replaceRange(match.start, match.end, ' '));
  return (amount: amount, item: item.isEmpty ? 'that' : item);
}

String _itemName(String text) => text
    .replaceAll(RegExp(r'[?!.,]'), ' ')
    .replaceAll(
      RegExp(
        r"\b(can|could|i|i'm|im|afford|it|a|an|the|for|buy|get|should|"
        r'purchase|is|it|ok|okay|to|me|my|myself|want|wanna|thinking|about|'
        r'of|getting|buying|new|some|pair|on|splurge|treat|worth)\b',
        caseSensitive: false,
      ),
      ' ',
    )
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

final _purchaseWords = RegExp(
  r'\b(afford|buy|buying|purchase|splurge|treat myself|worth it|spend on)\b'
  r"|\b(should|can|could|may) i (get|order|grab)\b|\bis it ok to (get|order)\b",
  caseSensitive: false,
);

/// Questions about the budget itself ("How much can I afford to spend this
/// week?"), not about one thing to buy.
final _budgetQuestion = RegExp(
  r'^\s*(how much|how many|what|when|why|where|which)\b',
  caseSensitive: false,
);

/// The thing being asked about when a question is about buying something
/// but gives no price ("Can I afford a Dior wallet?"), else null. Without a
/// price nobody can say yes or no, so the coach asks for it.
String? purchaseWithoutPrice(String text) {
  if (parseQuestion(text) != null ||
      !_purchaseWords.hasMatch(text) ||
      _budgetQuestion.hasMatch(text)) {
    return null;
  }
  final item = _itemName(text);
  return item.isEmpty ? 'it' : item;
}

/// Asks for the price of [item] instead of guessing.
String askForPrice(String item) => item == 'it'
    ? 'How much does it cost? Tell me the price, like "Shoes \$80", and '
          'I\'ll check it against your runway.'
    : 'How much is the $item? Tell me the price, like "$item \$80", and '
          'I\'ll check it against your runway.';

Assessment assess(double amount, String item, CoachGrounding g) {
  final dailyBefore = g.dailyAllowance;
  final dailyAfter =
      (g.available - amount + g.spentToday + g.putAsideToday) / g.daysLeft;
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

  final share = amount > g.available
      ? 'That\'s more than the ${money(math.max(0, g.available), cents: false)} '
            'you have left this ${g.period.noun}.'
      : 'That would eat ${(amount / g.available * 100).round()}% of what you '
            'have left.';
  final steady = SavingsPlan.forShare(amount, g, 0.2);
  final quick = SavingsPlan.forShare(amount, g, 1 / 3);
  final faster = steady != null && quick != null && quick.days < steady.days
      ? quick
      : null;
  final String plan;
  if (steady == null) {
    plan =
        ' There\'s nothing spare to save from right now. Get back under your '
        'daily number first, then put a little aside for it.';
  } else {
    final ready = steady.days <= g.daysLeft
        ? ', before this ${g.period.noun} ends'
        : '';
    plan =
        ' Put ${money(steady.perDay, cents: false)} a day aside and you\'ll '
        'have it in ${steady.howLong}$ready'
        '${faster == null ? '' : ', or ${money(faster.perDay, cents: false)} '
                  'a day to get it in ${faster.howLong}'}.';
  }
  return Assessment(
    plan: steady,
    fasterPlan: faster,
    period: g.period,
    verdict: Verdict.no,
    item: item,
    amount: amount,
    dailyBefore: dailyBefore,
    dailyAfter: dailyAfter,
    runwayDaysLost: daysLost,
    message: '$share$plan',
  );
}

/// Saving [perDay] out of the daily allowance pays for something in [days].
class SavingsPlan {
  const SavingsPlan({required this.perDay, required this.days});

  /// Putting [share] of the daily allowance aside each day, rounded to a
  /// friendly amount. Null when there's no allowance left to save from.
  static SavingsPlan? forShare(double amount, CoachGrounding g, double share) {
    if (g.dailyAllowance < 1) return null;
    final raw = g.dailyAllowance * share;
    final perDay = raw < 10
        ? math.max(1.0, raw.roundToDouble())
        : math.max(10.0, (raw / 5).round() * 5.0);
    return SavingsPlan(perDay: perDay, days: (amount / perDay).ceil());
  }

  final double perDay;
  final int days;

  double get perWeek => perDay * 7;

  /// "5 days", "3 weeks", "4 months".
  String get howLong => days < 14
      ? plural(days, 'day')
      : days < 60
      ? plural((days / 7).ceil(), 'week')
      : plural((days / 30).ceil(), 'month');
}

enum _SmallTalk { hello, thanks, bye, ok }

const _smallTalk = {
  _SmallTalk.hello: r"(hi+|hey+|hello+|hiya|yo|sup|what'?s up|good (morning|afternoon|evening))",
  _SmallTalk.thanks:
      r'(thanks|thank you( so much)?|thx|ty|tysm|appreciate it|cheers)',
  _SmallTalk.bye:
      r'(bye+( bye)?|good ?bye|see (you|ya)( later)?|cya|later|good ?night|gn)',
  _SmallTalk.ok:
      r'(ok(ay)?|k|cool|nice|got it|great|alright|sounds good|perfect|lol)',
};

/// A friendly reply to "hi", "thanks", "bye" or "ok", or null for anything
/// else. Answered by the rules everywhere, so the model never has to decide
/// whether a goodbye is off-topic.
String? smallTalk(String text, CoachGrounding g) {
  final said = text
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z' ]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (said.isEmpty) return null;
  final kind = _smallTalk.entries
      .where(
        (e) =>
            RegExp('^(${e.value})( (coach|runway|man|bro|dude))?\$')
                .hasMatch(said),
      )
      .map((e) => e.key)
      .firstOrNull;
  if (kind == null) return null;
  final safe = g.safeToSpendToday;
  final today = safe >= 0
      ? 'You\'ve got ${money(safe)} safe to spend today'
      : 'You\'re ${money(-safe)} over today\'s budget';
  return switch (kind) {
    _SmallTalk.hello => '$today. Thinking about buying something?',
    _SmallTalk.thanks => 'Anytime! Ask me before your next purchase.',
    _SmallTalk.bye =>
      safe >= 0
          ? 'Bye! ${today.replaceFirst('You\'ve', 'You\'ve still')}.'
          : 'Bye! Go easy for the rest of today: ${today.toLowerCase()}.',
    _SmallTalk.ok =>
      'Sounds good. I\'m here whenever you want to check a '
          'purchase.',
  };
}

/// Rule-based coach that runs entirely on-device.
class LocalCoach implements AffordabilityCoach {
  const LocalCoach();

  @override
  Future<CoachReply> ask(String question, CoachGrounding grounding) async {
    if (smallTalk(question, grounding) case final reply?) {
      return CoachReply.text(reply);
    }
    final parsed = parseQuestion(question);
    final unpriced = purchaseWithoutPrice(question);
    if (unpriced != null) return CoachReply.text(askForPrice(unpriced));
    if (parsed == null) {
      if (grounding.history case final history?) {
        if (answerSpendingQuestion(question, history) case final answer?) {
          return CoachReply.text(answer);
        }
      }
      return const CoachReply.text(
        'I\'m your money coach, so I stick to your budget. Tell me what it '
        'costs — like "Concert ticket \$60" — and I\'ll run it against your '
        'runway, or ask what you spent, like "Spent last week?"',
      );
    }
    return CoachReply.assessment(assess(parsed.amount, parsed.item, grounding));
  }

  @override
  Future<CoachReply> describeWeek(WeekRecap week) async =>
      CoachReply.text(week.summary);
}
