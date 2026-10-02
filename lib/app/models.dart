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
  });

  final String id;
  final double amount;
  final ExpenseCategory category;
  final bool isNeed;
  final DateTime date;
  final String? note;

  String get title => note ?? category.label;
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
  });

  final String id;
  final String emoji;
  final String name;
  final double amount;
  final DateTime dueDate;
}

class Term {
  const Term({
    required this.name,
    required this.start,
    required this.end,
    required this.startingBalance,
  });

  final String name;
  final DateTime start;
  final DateTime end;
  final double startingBalance;
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
    required this.friends,
    required this.splits,
    required this.challengeStart,
  });

  final Term term;
  final List<Expense> expenses;
  final List<UpcomingCost> upcoming;
  final List<Friend> friends;
  final List<BillSplit> splits;
  final DateTime challengeStart;
}
