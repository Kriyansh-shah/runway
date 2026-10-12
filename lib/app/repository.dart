/// Persistence boundary. [AppState] only depends on [BudgetRepository]:
/// [DriftBudgetRepository] saves to SQLite on the device, and
/// [MockBudgetRepository] keeps everything in memory (tests, demos).
library;

import 'dart:math' as math;

import 'auth.dart';
import 'models.dart';

abstract interface class BudgetRepository {
  Future<BudgetData> load();

  /// The remembered signed-in user, or null when signed out.
  Future<UserProfile?> currentUser();
  Future<void> setCurrentUser(UserProfile? user);

  Future<void> setAppLock(bool on);

  Future<void> addExpense(Expense expense);

  /// Saves new amount, category, need/want and note; the date stays.
  Future<void> updateExpense(Expense expense);

  /// Soft delete, so [restoreExpense] can undo it.
  Future<void> deleteExpense(String expenseId);
  Future<void> restoreExpense(String expenseId);

  /// Saves every roommate IOU plus your own share together — all or nothing.
  Future<void> splitBill(List<BillSplit> splits, Expense myShare);
  Future<void> settleSplit(String splitId);

  /// Saves the edited term; [added] are bills reserved for days it gained.
  Future<void> saveTerm(Term term, {List<UpcomingCost> added = const []});
  Future<void> addUpcomingCost(UpcomingCost cost);

  /// Saves a one-off cost's new name, amount or due date.
  Future<void> updateUpcomingCost(UpcomingCost cost);

  /// Saves a bill's new name and amount, and gives them to its unpaid
  /// months due on or after [from].
  Future<void> updateBill(RepeatingBill bill, {required DateTime from});

  /// Saves the payment's new details. [continuedBy] is added with it, in
  /// one go, when a repeating payment carries on with a new amount.
  Future<void> updateIncome(Income income, {Income? continuedBy});

  /// Saves a new repeating bill and the months of it reserved so far.
  Future<void> addBill(RepeatingBill bill, List<UpcomingCost> due);

  /// No more months of the bill after [from]: its unpaid ones due on or
  /// after [from] are removed. Months already paid stay in history.
  Future<void> stopBill(String billId, {required DateTime from});
  Future<void> deleteUpcomingCost(String costId);

  /// Marks the cost paid and logs [expense] for it together — all or nothing.
  Future<void> payUpcomingCost(String costId, Expense expense);

  Future<void> addIncome(Income income);

  /// A repeating payment stops after [endsOn]; earlier paydays still count.
  Future<void> stopIncome(String incomeId, DateTime endsOn);

  /// Removes the payment entirely, as if it was never added.
  Future<void> deleteIncome(String incomeId);

  /// Replaces the current term with the user's own: the old term (and its
  /// expenses) is archived, repeating bills are stopped, and [term] starts
  /// empty with [upcoming] reserved.
  Future<void> startTerm(Term term, List<UpcomingCost> upcoming);

  /// A monthly budget moves on to [term]: the old month (and its expenses)
  /// is archived, its unpaid costs move to [term] along with [added], and
  /// [incomes] (copies of the pay that keeps coming) start in [term].
  Future<void> startNewMonth(
    Term term, {
    required List<Income> incomes,
    required List<UpcomingCost> added,
  });

  /// Finished terms and months, newest first. The demo term shown before
  /// setup isn't included.
  Future<List<PastTerm>> history();

  /// The end of the latest term or month whose recap was shown, or null if
  /// recaps have never run.
  Future<DateTime?> recapSeenUntil();
  Future<void> setRecapSeenUntil(DateTime endedOn);

  /// Permanently deletes everything on the device, including the session.
  /// The next [load] starts over as a brand-new install.
  Future<void> eraseEverything();
}

/// Nothing is saved: every launch starts from the same demo data.
class MockBudgetRepository implements BudgetRepository {
  MockBudgetRepository({DateTime? now}) : _now = now ?? DateTime.now();

  final DateTime _now;
  UserProfile? _user;

  @override
  Future<BudgetData> load() async => seed(_now);

  @override
  Future<UserProfile?> currentUser() async => _user;

  @override
  Future<void> setCurrentUser(UserProfile? user) async => _user = user;

  @override
  Future<void> setAppLock(bool on) async {}

  @override
  Future<void> addExpense(Expense expense) async {}

  @override
  Future<void> updateExpense(Expense expense) async {}

  @override
  Future<void> deleteExpense(String expenseId) async {}

  @override
  Future<void> restoreExpense(String expenseId) async {}

  @override
  Future<void> splitBill(List<BillSplit> splits, Expense myShare) async {}

  @override
  Future<void> settleSplit(String splitId) async {}

  @override
  Future<void> saveTerm(
    Term term, {
    List<UpcomingCost> added = const [],
  }) async {}

  @override
  Future<void> addUpcomingCost(UpcomingCost cost) async {}

  @override
  Future<void> updateUpcomingCost(UpcomingCost cost) async {}

  @override
  Future<void> updateBill(RepeatingBill bill, {required DateTime from}) async {}

  @override
  Future<void> updateIncome(Income income, {Income? continuedBy}) async {}

  @override
  Future<void> addBill(RepeatingBill bill, List<UpcomingCost> due) async {}

  @override
  Future<void> stopBill(String billId, {required DateTime from}) async {}

  @override
  Future<void> deleteUpcomingCost(String costId) async {}

  @override
  Future<void> payUpcomingCost(String costId, Expense expense) async {}

  @override
  Future<void> addIncome(Income income) async {}

  @override
  Future<void> stopIncome(String incomeId, DateTime endsOn) async {}

  @override
  Future<void> deleteIncome(String incomeId) async {}

  @override
  Future<void> startTerm(Term term, List<UpcomingCost> upcoming) async {}

  @override
  Future<void> startNewMonth(
    Term term, {
    required List<Income> incomes,
    required List<UpcomingCost> added,
  }) async {}

  @override
  Future<List<PastTerm>> history() async => const [];

  DateTime? _recapSeenUntil;

  @override
  Future<DateTime?> recapSeenUntil() async => _recapSeenUntil;

  @override
  Future<void> setRecapSeenUntil(DateTime endedOn) async =>
      _recapSeenUntil = endedOn;

  @override
  Future<void> eraseEverything() async => _user = null;

  /// Total of the seeded past expenses. Tuned so the demo lands at
  /// "14 days short" with today's coffee included.
  static const seededTotal = 1170.0;

  /// Deterministic demo data relative to [now].
  static BudgetData seed(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    DateTime day(int offset) =>
        DateTime(today.year, today.month, today.day + offset);

    final rng = math.Random(42);
    final raw = <Expense>[];
    var n = 0;
    for (var d = -40; d <= -1; d++) {
      // A gap 13 days ago so the streak is a believable 13 (with today), plus a few
      // random gaps earlier in the term.
      if (d == -13 || (d < -13 && rng.nextDouble() < 0.15)) continue;
      final count = 1 + rng.nextInt(3);
      for (var i = 0; i < count; i++) {
        var p = ExpensePreset.all[rng.nextInt(ExpensePreset.all.length)];
        // You've been good during the no-delivery challenge so far.
        if (d >= -3 && p.category == ExpenseCategory.delivery) {
          p = ExpensePreset.all.first;
        }
        final jitter = 0.7 + rng.nextDouble() * 0.6;
        raw.add(
          Expense(
            id: 'seed-${n++}',
            amount: p.amount * jitter,
            category: p.category,
            isNeed: p.isNeed,
            date: day(d).add(Duration(hours: 8 + rng.nextInt(14))),
          ),
        );
      }
    }

    // Scale to the target total, rounding to cents, and absorb the rounding
    // error into the last item so the total is exact.
    final rawTotal = raw.fold<double>(0, (s, e) => s + e.amount);
    final scale = seededTotal / rawTotal;
    final expenses = <Expense>[];
    var running = 0.0;
    for (var i = 0; i < raw.length; i++) {
      final e = raw[i];
      final amount = i == raw.length - 1
          ? ((seededTotal - running) * 100).round() / 100
          : (e.amount * scale * 100).round() / 100;
      running += amount;
      expenses.add(
        Expense(
          id: e.id,
          amount: amount,
          category: e.category,
          isNeed: e.isNeed,
          date: e.date,
        ),
      );
    }
    expenses.add(
      Expense(
        id: 'seed-today',
        amount: 4.50,
        category: ExpenseCategory.coffee,
        isNeed: false,
        date: today.add(const Duration(hours: 9)),
      ),
    );

    final challengeStart = day(-3);
    return BudgetData(
      term: Term(
        name: 'Fall term',
        start: day(-40),
        end: day(70),
        startingBalance: 3200,
      ),
      expenses: expenses,
      upcoming: [
        UpcomingCost(
          id: 'phone',
          emoji: '📱',
          name: 'Phone bill',
          amount: 55,
          dueDate: day(9),
        ),
        UpcomingCost(
          id: 'formal',
          emoji: '🎟️',
          name: 'Formal ticket',
          amount: 85,
          dueDate: day(23),
        ),
        UpcomingCost(
          id: 'flight',
          emoji: '✈️',
          name: 'Flight home',
          amount: 280,
          dueDate: day(54),
        ),
      ],
      friends: const [
        Friend(
          id: 'maya',
          name: 'Maya',
          emoji: '🦊',
          streak: 21,
          noDeliveryDays: [true, true, true, true],
        ),
        Friend(
          id: 'aarav',
          name: 'Aarav',
          emoji: '🐼',
          streak: 9,
          noDeliveryDays: [true, false, true, true],
        ),
        Friend(
          id: 'jules',
          name: 'Jules',
          emoji: '🐸',
          streak: 4,
          noDeliveryDays: [true, true, false, false],
        ),
      ],
      splits: const [
        BillSplit(
          id: 'pizza',
          person: 'Aarav',
          amount: 12.40,
          note: 'Pizza night',
          theyOweYou: true,
        ),
        BillSplit(
          id: 'wifi',
          person: 'Maya',
          amount: 30,
          note: 'Wi-Fi + power',
          theyOweYou: false,
        ),
      ],
      challengeStart: challengeStart,
    );
  }
}
