/// Plain data types. Kept free of Flutter imports so they can be mapped to
/// SQLite rows later without dragging UI code along.
library;

enum ExpenseCategory {
  coffee('☕', 'Coffee'),
  groceries('🛒', 'Groceries'),
  transit('🚇', 'Transit'),
  lateNight('🍕', 'Late-night food'),
  delivery('📦', 'Delivery'),
  supplies('📚', 'Supplies'),
  rideshare('🚕', 'Uber / ride'),
  travel('✈️', 'Travel'),
  eatingOut('🍔', 'Eating out'),
  shopping('🛍️', 'Shopping'),
  fun('🎉', 'Fun'),
  bills('🧾', 'Bills'),
  other('💸', 'Other');

  const ExpenseCategory(this.emoji, this.label);
  final String emoji;
  final String label;
}

/// A category the person made themselves, like 🚬 Cigarettes. Expenses in
/// it are saved as [ExpenseCategory.other] plus a link to it, so deleting
/// it just leaves them in Other.
class CustomCategory {
  const CustomCategory({
    required this.id,
    required this.emoji,
    required this.name,
  });

  final String id;
  final String emoji;
  final String name;

  CustomCategory copyWith({String? emoji, String? name}) => CustomCategory(
    id: id,
    emoji: emoji ?? this.emoji,
    name: name ?? this.name,
  );
}

/// What an expense is filed under, for showing and adding up: a built-in
/// category or a custom one. Two refs to the same custom category are
/// equal even if one has an older name.
class CategoryRef {
  const CategoryRef(this.category, [this.custom]);

  final ExpenseCategory category;
  final CustomCategory? custom;

  String get emoji => custom?.emoji ?? category.emoji;
  String get label => custom?.name ?? category.label;

  @override
  bool operator ==(Object other) =>
      other is CategoryRef &&
      other.category == category &&
      other.custom?.id == custom?.id;

  @override
  int get hashCode => Object.hash(category, custom?.id);
}

class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.isNeed,
    required this.date,
    this.note,
    this.planned = false,
    this.custom,
  });

  final String id;
  final double amount;

  /// [ExpenseCategory.other] when [custom] is set.
  final ExpenseCategory category;

  /// The person's own category, if it's filed under one.
  final CustomCategory? custom;
  final bool isNeed;
  final DateTime date;
  final String? note;

  /// Paid from a reserved upcoming cost. It still leaves the balance, but
  /// it isn't day-to-day spending: the money was set aside in advance.
  final bool planned;

  CategoryRef get filedUnder => CategoryRef(category, custom);

  String get title => note ?? filedUnder.label;

  /// The same expense with new details; the id, date and [planned] stay.
  Expense copyWith({
    double? amount,
    ExpenseCategory? category,
    bool? isNeed,
    String? Function()? note,
    CustomCategory? Function()? custom,
  }) => Expense(
    id: id,
    amount: amount ?? this.amount,
    category: category ?? this.category,
    isNeed: isNeed ?? this.isNeed,
    date: date,
    note: note == null ? this.note : note(),
    planned: planned,
    custom: custom == null ? this.custom : custom(),
  );
}

/// One-tap preset on the Quick Add sheet.
class ExpensePreset {
  const ExpensePreset(this.category, this.amount, {required this.isNeed});
  final ExpenseCategory category;
  final double amount;
  final bool isNeed;

  static const all = [
    ExpensePreset(ExpenseCategory.coffee, 4.50, isNeed: false),
    ExpensePreset(ExpenseCategory.groceries, 38, isNeed: true),
    ExpensePreset(ExpenseCategory.transit, 2.90, isNeed: true),
    ExpensePreset(ExpenseCategory.lateNight, 14, isNeed: false),
    ExpensePreset(ExpenseCategory.delivery, 22, isNeed: false),
    ExpensePreset(ExpenseCategory.supplies, 12, isNeed: true),
  ];
}

/// A big known cost that is reserved ahead of time.
class UpcomingCost {
  const UpcomingCost({
    required this.id,
    required this.emoji,
    required this.name,
    required this.amount,
    required this.dueDate,
    this.billId,
  });

  final String id;
  final String emoji;
  final String name;
  final double amount;
  final DateTime dueDate;

  /// Set when this is one month of a [RepeatingBill].
  final String? billId;

  bool get repeats => billId != null;

  /// The same cost with new details; the id and [billId] stay.
  UpcomingCost copyWith({String? name, double? amount, DateTime? dueDate}) =>
      UpcomingCost(
        id: id,
        emoji: emoji,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        dueDate: dueDate ?? this.dueDate,
        billId: billId,
      );
}

/// A bill due every month (rent, phone, subscriptions) on [firstDue]'s day
/// of the month, or the last day of shorter months. Each month's bill is
/// reserved as its own [UpcomingCost], so it can be paid on its own.
class RepeatingBill {
  const RepeatingBill({
    required this.id,
    required this.emoji,
    required this.name,
    required this.amount,
    required this.firstDue,
  });

  final String id;
  final String emoji;
  final String name;
  final double amount;
  final DateTime firstDue;

  RepeatingBill copyWith({String? name, double? amount}) => RepeatingBill(
    id: id,
    emoji: emoji,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    firstDue: firstDue,
  );
}

/// How often money comes in. [once] is a single payment (scholarship,
/// project payment, gift); the rest repeat from the first payday.
enum IncomeFrequency {
  once('One-time'),
  weekly('Weekly'),
  biweekly('Every 2 weeks'),
  monthly('Monthly');

  const IncomeFrequency(this.label);
  final String label;
}

/// Money coming in during the term. It counts toward the balance only on
/// the days it actually arrives, never ahead of time.
class Income {
  const Income({
    required this.id,
    required this.name,
    required this.amount,
    required this.frequency,
    required this.firstDate,
    this.endsOn,
  });

  final String id;
  final String name;

  /// Amount of each payment.
  final double amount;
  final IncomeFrequency frequency;

  /// The first (or only) payday.
  final DateTime firstDate;

  /// Last day a repeating payment can arrive, once it has been stopped.
  final DateTime? endsOn;

  bool get repeats => frequency != IncomeFrequency.once;

  Income copyWith({
    String? id,
    String? name,
    double? amount,
    DateTime? firstDate,
    DateTime? endsOn,
  }) => Income(
    id: id ?? this.id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    frequency: frequency,
    firstDate: firstDate ?? this.firstDate,
    endsOn: endsOn ?? this.endsOn,
  );
}

/// How the user budgets. A semester runs between dates they pick; a
/// monthly budget runs to the end of the calendar month and then starts the
/// next month by itself.
enum BudgetPeriod {
  semester('Semester', 'semester'),
  monthly('Monthly', 'month');

  const BudgetPeriod(this.label, this.noun);
  final String label;

  /// Lowercase, for sentences: "Money lasts the whole month".
  final String noun;
}

class Term {
  const Term({
    required this.name,
    required this.start,
    required this.end,
    required this.startingBalance,
    this.period = BudgetPeriod.semester,
    this.savingsGoal = 0,
  });

  final String name;
  final DateTime start;
  final DateTime end;
  final double startingBalance;
  final BudgetPeriod period;

  /// Money to save this term or month. It's set aside on day one, like a
  /// big cost, so the daily budget only spreads what's left.
  final double savingsGoal;

  Term copyWith({double? savingsGoal}) => Term(
    name: name,
    start: start,
    end: end,
    startingBalance: startingBalance,
    period: period,
    savingsGoal: savingsGoal ?? this.savingsGoal,
  );
}

/// How a finished term or month went for saving.
class SavedTerm {
  const SavedTerm({
    required this.name,
    required this.period,
    required this.goal,
    required this.saved,
  });

  final String name;
  final BudgetPeriod period;
  final double goal;

  /// What was actually kept: the goal, less anything spent out of it.
  final double saved;

  bool get hitGoal => goal > 0 && saved >= goal - 0.005;
}

/// A finished semester or month, kept on the phone for History.
class PastTerm {
  const PastTerm({
    required this.term,
    required this.endedOn,
    required this.expenses,
    required this.incomes,
    this.saved = 0,
  });

  final Term term;

  /// How much of [Term.savingsGoal] was kept when it ended.
  final double saved;

  /// When it was put away: after its last day, or earlier if a new
  /// semester was started before it ended.
  final DateTime endedOn;
  final List<Expense> expenses;
  final List<Income> incomes;
}

/// Something the person is saving up for, like a Dior wallet, apart from
/// the term's savings goal. Money put in is set aside from spending money
/// (and stays set aside when the term or month rolls over) until the
/// thing is bought or the goal is dropped.
class SavingsJar {
  const SavingsJar({
    required this.id,
    required this.name,
    required this.target,
    required this.createdAt,
    this.deposits = const [],
  });

  final String id;
  final String name;
  final double target;
  final DateTime createdAt;

  /// Every time money went in, oldest first.
  final List<JarDeposit> deposits;

  double get saved => deposits.fold(0, (sum, d) => sum + d.amount);

  /// Still to put in; 0 once it's full.
  double get remaining => target - saved > 0.005 ? target - saved : 0;

  bool get full => remaining == 0;

  SavingsJar withDeposit(JarDeposit deposit) => SavingsJar(
    id: id,
    name: name,
    target: target,
    createdAt: createdAt,
    deposits: [...deposits, deposit],
  );
}

/// Money moved into a [SavingsJar] on [date]; negative when it was taken
/// back out (the goal was bought or dropped).
class JarDeposit {
  const JarDeposit({
    required this.id,
    required this.jarId,
    required this.amount,
    required this.date,
  });

  final String id;
  final String jarId;
  final double amount;
  final DateTime date;
}

class Friend {
  const Friend({
    required this.id,
    required this.name,
    required this.emoji,
    required this.streak,
    required this.noDeliveryDays,
  });

  final String id;
  final String name;
  final String emoji;
  final int streak;

  /// One entry per elapsed challenge day: true = stayed delivery-free.
  final List<bool> noDeliveryDays;
}

class BillSplit {
  const BillSplit({
    required this.id,
    required this.person,
    required this.amount,
    required this.note,
    required this.theyOweYou,
  });

  final String id;
  final String person;
  final double amount;
  final String note;
  final bool theyOweYou;
}

/// Everything the app loads at startup.
class BudgetData {
  const BudgetData({
    required this.term,
    required this.expenses,
    required this.upcoming,
    this.bills = const [],
    this.incomes = const [],
    this.customCategories = const [],
    this.savingsHistory = const [],
    this.savingsAsked = false,
    this.jars = const [],
    this.jarDeposits = const [],
    required this.friends,
    required this.splits,
    required this.challengeStart,
    this.needsSetup = false,
    this.appLock = false,
  });

  final Term term;
  final List<Expense> expenses;
  final List<UpcomingCost> upcoming;

  /// Repeating bills that haven't been stopped.
  final List<RepeatingBill> bills;
  final List<Income> incomes;

  /// The person's own categories, most recently used first.
  final List<CustomCategory> customCategories;

  /// Finished terms and months of your own, newest first.
  final List<SavedTerm> savingsHistory;

  /// The person has been asked for a savings goal (at setup, or by the
  /// card on Home), so Home stops asking.
  final bool savingsAsked;

  /// What the person is saving up for, oldest first. Bought and dropped
  /// ones aren't included.
  final List<SavingsJar> jars;

  /// Every deposit into any jar, open or not, oldest first: a jar bought
  /// this month still moved money this month.
  final List<JarDeposit> jarDeposits;
  final List<Friend> friends;
  final List<BillSplit> splits;
  final DateTime challengeStart;

  /// True until the user has entered their own term (still on demo data).
  final bool needsSetup;

  /// Face ID / passcode lock is on.
  final bool appLock;
}
