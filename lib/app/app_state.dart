import 'dart:async';

import 'package:flutter/widgets.dart';

import 'budget_math.dart';
import 'coach.dart';
import 'format.dart';
import 'models.dart';
import 'repository.dart';

/// Single source of truth for the app. Derived numbers are cached and
/// recomputed only when the underlying data changes.
class AppState extends ChangeNotifier {
  AppState({
    required BudgetRepository repository,
    required BudgetData data,
    this.coach = const LocalCoach(),
    DateTime Function()? clock,
  }) : _repo = repository,
       _clock = clock ?? DateTime.now,
       _term = data.term,
       _expenses = [...data.expenses],
       _upcoming = [...data.upcoming],
       _friends = data.friends,
       _splits = [...data.splits],
       challengeStart = data.challengeStart {
    _recompute();
  }

  final BudgetRepository _repo;
  final DateTime Function() _clock;
  final AffordabilityCoach coach;
  final DateTime challengeStart;

  Term _term;
  final List<Expense> _expenses;
  final List<UpcomingCost> _upcoming;
  final List<Friend> _friends;
  final List<BillSplit> _splits;

  late RunwaySnapshot _snapshot;
  late int _streak;

  DateTime get today => dateOnly(_clock());
  Term get term => _term;
  RunwaySnapshot get snapshot => _snapshot;
  int get streak => _streak;
  PetMood get mood => moodFor(_snapshot);
  PetLevel get petLevel => PetLevel.fromStreak(_streak);
  NeedWantSplit get thisWeek => weekSplit(_expenses, today);
  List<Friend> get friends => _friends;
  List<BillSplit> get splits => List.unmodifiable(_splits);

  /// Newest first.
  List<Expense> recentExpenses([int count = 6]) {
    final sorted = [..._expenses]..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(count).toList();
  }

  List<UpcomingCost> get comingUp =>
      _upcoming.where((c) => !c.dueDate.isBefore(today)).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  int get challengeDay => daysBetween(challengeStart, today) + 1;

  /// Your own no-delivery dots, derived from what you actually logged.
  List<bool> get myNoDeliveryDays => [
    for (var i = 0; i < challengeDay.clamp(0, 7); i++)
      !_expenses.any(
        (e) =>
            e.category == ExpenseCategory.delivery &&
            daysBetween(challengeStart, e.date) == i,
      ),
  ];

  CoachGrounding get grounding => CoachGrounding.fromSnapshot(_snapshot);

  void addExpense({
    required double amount,
    required ExpenseCategory category,
    required bool isNeed,
    String? note,
  }) {
    final expense = Expense(
      id: 'e${DateTime.now().microsecondsSinceEpoch}',
      amount: amount,
      category: category,
      isNeed: isNeed,
      date: _clock(),
      note: note,
    );
    _expenses.add(expense);
    _recompute();
    notifyListeners();
    unawaited(_repo.addExpense(expense));
  }

  /// You paid [total] for something shared with [roommates]. Each roommate
  /// now owes you an even share, and only your own share counts as spending.
  void splitBill({
    required String description,
    required double total,
    required List<Friend> roommates,
    required ExpenseCategory category,
    required bool isNeed,
  }) {
    if (roommates.isEmpty || total <= 0) return;
    final shares = splitEvenly(total, roommates.length);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final added = [
      for (final r in roommates)
        BillSplit(
          id: 's$stamp-${r.id}',
          person: r.name,
          amount: shares.each,
          note: description,
          theyOweYou: true,
        ),
    ];
    _splits.insertAll(0, added);
    for (final split in added) {
      unawaited(_repo.addSplit(split));
    }
    // addExpense recomputes and notifies for both changes.
    addExpense(
      amount: shares.mine,
      category: category,
      isNeed: isNeed,
      note: description,
    );
  }

  void settleSplit(String id) {
    _splits.removeWhere((s) => s.id == id);
    notifyListeners();
    unawaited(_repo.settleSplit(id));
  }

  void updateTerm(Term term) {
    _term = term;
    _recompute();
    notifyListeners();
  }

  void addUpcomingCost(UpcomingCost cost) {
    _upcoming.add(cost);
    _recompute();
    notifyListeners();
  }

  void _recompute() {
    final now = today;
    _snapshot = computeRunway(
      term: _term,
      expenses: _expenses,
      upcoming: _upcoming,
      today: now,
    );
    _streak = computeStreak(_expenses, now);
  }
}

/// Exposes [AppState] to the tree; widgets that call [AppScope.of] rebuild
/// when it notifies.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing (for callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
