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

class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.isNeed,
    required this.date,
    this.note,
    this.planned = false,
  });

  final String id;
  final double amount;
  final ExpenseCategory category;
  final bool isNeed;
  final DateTime date;
  final String? note;

  /// Paid from a reserved upcoming cost. It still leaves the balance, but
  /// it isn't day-to-day spending: the money was set aside in advance.
  final bool planned;

  String get title => note ?? category.label;

  /// The same expense with new details; the id, date and [planned] stay.
  Expense copyWith({
    double? amount,
    ExpenseCategory? category,
    bool? isNeed,
    String? Function()? note,
  }) => Expense(
    id: id,
    amount: amount ?? this.amount,
    category: category ?? this.category,
    isNeed: isNeed ?? this.isNeed,
    date: date,
    note: note == null ? this.note : note(),
    planned: planned,
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

  Income copyWith({String? id, DateTime? endsOn}) => Income(
    id: id ?? this.id,
    name: name,
    amount: amount,
    frequency: frequency,
    firstDate: firstDate,
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
  });

  final String name;
  final DateTime start;
  final DateTime end;
  final double startingBalance;
  final BudgetPeriod period;
}

/// A finished semester or month, kept on the phone for History.
class PastTerm {
  const PastTerm({
    required this.term,
    required this.endedOn,
    required this.expenses,
    required this.incomes,
  });

  final Term term;

  /// When it was put away: after its last day, or earlier if a new
  /// semester was started before it ended.
  final DateTime endedOn;
  final List<Expense> expenses;
  final List<Income> incomes;
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
  final List<Friend> friends;
  final List<BillSplit> splits;
  final DateTime challengeStart;

  /// True until the user has entered their own term (still on demo data).
  final bool needsSetup;

  /// Face ID / passcode lock is on.
  final bool appLock;
}
