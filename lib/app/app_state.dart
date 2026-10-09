import 'dart:async';

import 'package:flutter/widgets.dart';

import 'auth.dart';
import 'budget_math.dart';
import 'budget_math.dart' as budget show nextIncome;
import 'coach.dart';
import 'format.dart';
import 'models.dart';
import 'purchase_link.dart';
import 'repository.dart';

/// Single source of truth for the app. Derived numbers are cached and
/// recomputed only when the underlying data changes.
class AppState extends ChangeNotifier {
  AppState({
    required BudgetRepository repository,
    required BudgetData data,
    this.coach = const LocalCoach(),
    this.auth = const LocalAuthService(),
    UserProfile? user,
    DateTime Function()? clock,
  }) : _repo = repository,
       _clock = clock ?? DateTime.now,
       _term = data.term,
       _expenses = [...data.expenses],
       _upcoming = [...data.upcoming],
       _incomes = [...data.incomes],
       _friends = [...data.friends],
       _splits = [...data.splits],
       _needsSetup = data.needsSetup,
       _challengeStart = data.challengeStart {
    _user = user;
    _recompute();
  }

  final BudgetRepository _repo;
  final DateTime Function() _clock;
  final AffordabilityCoach coach;
  final AuthService auth;

  Term _term;
  final List<Expense> _expenses;
  final List<UpcomingCost> _upcoming;
  final List<Income> _incomes;
  final List<Friend> _friends;
  final List<BillSplit> _splits;
  DateTime _challengeStart;

  /// An Apple Pay purchase waiting to open in Quick Add. Set when a
  /// `runway://log` link arrives; Home picks it up once it's on screen.
  final pendingPurchase = ValueNotifier<ApplePayPurchase?>(null);

  UserProfile? _user;
  bool _needsSetup;
  late RunwaySnapshot _snapshot;
  late int _streak;

  DateTime get today => dateOnly(_clock());
  UserProfile? get user => _user;

  /// Still on demo data: show the setup flow before Home.
  bool get needsSetup => _needsSetup;
  Term get term => _term;
  RunwaySnapshot get snapshot => _snapshot;
  int get streak => _streak;
  PetMood get mood => moodFor(_snapshot);
  PetLevel get petLevel => PetLevel.fromStreak(_streak);
  NeedWantSplit get thisWeek => weekSplit(_expenses, today);
  List<Friend> get friends => List.unmodifiable(_friends);
  List<BillSplit> get splits => List.unmodifiable(_splits);
  DateTime get challengeStart => _challengeStart;

  /// Money coming in this term, oldest first.
  List<Income> get incomes => List.unmodifiable(_incomes);

  /// The next payment still to come this term, if any.
  ({Income income, DateTime date})? get nextIncome =>
      budget.nextIncome(_incomes, term: _term, today: today);

  /// Newest first.
  List<Expense> recentExpenses([int count = 6]) =>
      allExpenses.take(count).toList();

  /// Every expense this term, newest first.
  List<Expense> get allExpenses =>
      [..._expenses]..sort((a, b) => b.date.compareTo(a.date));

  /// Every unpaid cost, soonest (or most overdue) first.
  List<UpcomingCost> get comingUp =>
      [..._upcoming]..sort((a, b) => a.dueDate.compareTo(b.dueDate));

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

  /// Updates the screen immediately, then saves in the background.
  void addExpense({
    required double amount,
    required ExpenseCategory category,
    required bool isNeed,
    String? note,
  }) {
    _checkAmount(amount);
    final expense = _newExpense(amount, category, isNeed, note);
    _expenses.add(expense);
    _changed();
    _persist(_repo.addExpense(expense));
  }

  /// Replaces the expense with the same id (amount, category, need, note).
  void updateExpense(Expense expense) {
    _checkAmount(expense.amount);
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index < 0) return;
    _expenses[index] = expense;
    _changed();
    _persist(_repo.updateExpense(expense));
  }

  /// Removes the expense and returns it, so the caller can offer Undo
  /// through [restoreExpense]. Null if it's already gone.
  Expense? deleteExpense(String id) {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index < 0) return null;
    final removed = _expenses.removeAt(index);
    _changed();
    _persist(_repo.deleteExpense(id));
    return removed;
  }

  void restoreExpense(Expense expense) {
    if (_expenses.any((e) => e.id == expense.id)) return;
    _expenses.add(expense);
    _changed();
    _persist(_repo.restoreExpense(expense.id));
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
    final myShare = _newExpense(shares.mine, category, isNeed, description);
    _splits.insertAll(0, added);
    _expenses.add(myShare);
    _changed();
    _persist(_repo.splitBill(added, myShare));
  }

  void settleSplit(String id) {
    _splits.removeWhere((s) => s.id == id);
    notifyListeners();
    _persist(_repo.settleSplit(id));
  }

  void signedIn(UserProfile user) {
    _user = user;
    notifyListeners();
    _persist(_repo.setCurrentUser(user));
  }

  Future<void> signOut() async {
    await auth.signOut();
    _user = null;
    notifyListeners();
    await _repo.setCurrentUser(null);
  }

  void updateTerm(Term term) {
    if (term.name.trim().isEmpty ||
        !term.end.isAfter(term.start) ||
        !term.startingBalance.isFinite ||
        term.startingBalance < 0) {
      throw ArgumentError.value(term, 'term', 'invalid name, dates or balance');
    }
    _term = term;
    _changed();
    _persist(_repo.saveTerm(term));
  }

  void addUpcomingCost(UpcomingCost cost) {
    _checkAmount(cost.amount);
    _upcoming.add(cost);
    _changed();
    _persist(_repo.addUpcomingCost(cost));
  }

  void deleteUpcomingCost(String id) {
    _upcoming.removeWhere((c) => c.id == id);
    _changed();
    _persist(_repo.deleteUpcomingCost(id));
  }

  /// The reserved money is now actually spent: the cost leaves "Coming up"
  /// and is logged as a planned need under Bills, so today's budget and the
  /// burn rate don't move.
  void payUpcomingCost(String id) {
    final index = _upcoming.indexWhere((c) => c.id == id);
    if (index < 0) return;
    final cost = _upcoming.removeAt(index);
    final expense = _newExpense(
      cost.amount,
      ExpenseCategory.bills,
      true,
      cost.name,
      planned: true,
    );
    _expenses.add(expense);
    _changed();
    _persist(_repo.payUpcomingCost(id, expense));
  }

  void addIncome({
    required String name,
    required double amount,
    required IncomeFrequency frequency,
    required DateTime firstDate,
  }) {
    _checkAmount(amount);
    final income = Income(
      id: 'i${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      amount: amount,
      frequency: frequency,
      firstDate: dateOnly(firstDate),
    );
    _incomes.add(income);
    _changed();
    _persist(_repo.addIncome(income));
  }

  /// No more paydays after today; the ones already received still count.
  void stopIncome(String id) {
    final index = _incomes.indexWhere((i) => i.id == id);
    if (index < 0) return;
    final endsOn = today;
    _incomes[index] = _incomes[index].copyWith(endsOn: endsOn);
    _changed();
    _persist(_repo.stopIncome(id, endsOn));
  }

  /// Removes the income and every payment it brought in.
  void deleteIncome(String id) {
    _incomes.removeWhere((i) => i.id == id);
    _changed();
    _persist(_repo.deleteIncome(id));
  }

  /// Swaps the demo term for the user's own, starting with no expenses.
  void startTerm(Term term, List<UpcomingCost> upcoming) {
    _term = term;
    _expenses.clear();
    _upcoming
      ..clear()
      ..addAll(upcoming);
    _incomes.clear();
    _needsSetup = false;
    _changed();
    _persist(_repo.startTerm(term, upcoming));
  }

  /// Deletes everything on this device and signs out. Unlike other writes
  /// this waits for the database, so nothing is left behind if it fails.
  Future<void> eraseEverything() async {
    await auth.signOut();
    await _repo.eraseEverything();
    final data = await _repo.load();
    _term = data.term;
    _replace(_expenses, data.expenses);
    _replace(_upcoming, data.upcoming);
    _replace(_incomes, data.incomes);
    _replace(_friends, data.friends);
    _replace(_splits, data.splits);
    _challengeStart = data.challengeStart;
    _needsSetup = data.needsSetup;
    _user = null;
    _changed();
  }

  static void _replace<T>(List<T> list, List<T> items) => list
    ..clear()
    ..addAll(items);

  /// Amounts come from validated inputs; anything else is a bug.
  static void _checkAmount(double amount) {
    if (!amount.isFinite || amount <= 0 || amount >= 1000000) {
      throw ArgumentError.value(amount, 'amount', 'must be 0 < amount < 1M');
    }
  }

  Expense _newExpense(
    double amount,
    ExpenseCategory category,
    bool isNeed,
    String? note, {
    bool planned = false,
  }) => Expense(
    id: 'e${DateTime.now().microsecondsSinceEpoch}',
    amount: amount,
    category: category,
    isNeed: isNeed,
    date: _clock(),
    note: note,
    planned: planned,
  );

  void _changed() {
    _recompute();
    notifyListeners();
  }

  /// Saves without blocking the UI. A failed save is reported (red screen in
  /// debug, logged in release) instead of disappearing silently.
  void _persist(Future<void> write) {
    unawaited(
      write.catchError((Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'runway storage',
            context: ErrorDescription('while saving to the database'),
          ),
        );
      }),
    );
  }

  void _recompute() {
    final now = today;
    _snapshot = computeRunway(
      term: _term,
      expenses: _expenses,
      upcoming: _upcoming,
      incomes: _incomes,
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
