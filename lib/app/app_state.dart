import 'dart:async';

import 'package:flutter/widgets.dart';

import 'auth.dart';
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
    this.auth = const LocalAuthService(),
    UserProfile? user,
    DateTime Function()? clock,
  }) : _repo = repository,
       _clock = clock ?? DateTime.now,
       _term = data.term,
       _expenses = [...data.expenses],
       _upcoming = [...data.upcoming],
       _friends = data.friends,
       _splits = [...data.splits],
       _needsSetup = data.needsSetup,
       challengeStart = data.challengeStart {
    _user = user;
    _recompute();
  }

  final BudgetRepository _repo;
  final DateTime Function() _clock;
  final AffordabilityCoach coach;
  final AuthService auth;
  final DateTime challengeStart;

  Term _term;
  final List<Expense> _expenses;
  final List<UpcomingCost> _upcoming;
  final List<Friend> _friends;
  final List<BillSplit> _splits;

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

  /// Updates the screen immediately, then saves in the background.
  void addExpense({
    required double amount,
    required ExpenseCategory category,
    required bool isNeed,
    String? note,
  }) {
    final expense = _newExpense(amount, category, isNeed, note);
    _expenses.add(expense);
    _changed();
    _persist(_repo.addExpense(expense));
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
    _term = term;
    _changed();
    _persist(_repo.saveTerm(term));
  }

  void addUpcomingCost(UpcomingCost cost) {
    _upcoming.add(cost);
    _changed();
    _persist(_repo.addUpcomingCost(cost));
  }

  /// Swaps the demo term for the user's own, starting with no expenses.
  void startTerm(Term term, List<UpcomingCost> upcoming) {
    _term = term;
    _expenses.clear();
    _upcoming
      ..clear()
      ..addAll(upcoming);
    _needsSetup = false;
    _changed();
    _persist(_repo.startTerm(term, upcoming));
  }

  Expense _newExpense(
    double amount,
    ExpenseCategory category,
    bool isNeed,
    String? note,
  ) => Expense(
    id: 'e${DateTime.now().microsecondsSinceEpoch}',
    amount: amount,
    category: category,
    isNeed: isNeed,
    date: _clock(),
    note: note,
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
