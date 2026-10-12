import 'dart:async';

import 'package:flutter/widgets.dart';

import 'auth.dart';
import 'budget_math.dart';
import 'budget_math.dart' as budget show nextIncome;
import 'coach.dart';
import 'device_auth.dart';
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
    this.deviceAuth = const LocalDeviceAuth(),
    UserProfile? user,
    DateTime Function()? clock,
  }) : _repo = repository,
       _clock = clock ?? DateTime.now,
       _term = data.term,
       _expenses = [...data.expenses],
       _upcoming = [...data.upcoming],
       _bills = [...data.bills],
       _incomes = [...data.incomes],
       _friends = [...data.friends],
       _splits = [...data.splits],
       _needsSetup = data.needsSetup,
       _appLock = data.appLock,
       _challengeStart = data.challengeStart {
    _user = user;
    _recompute();
  }

  final BudgetRepository _repo;
  final DateTime Function() _clock;
  final AffordabilityCoach coach;

  /// Face ID / Touch ID / passcode prompt for the app lock.
  final DeviceAuth deviceAuth;

  Term _term;
  final List<Expense> _expenses;
  final List<UpcomingCost> _upcoming;
  final List<RepeatingBill> _bills;
  final List<Income> _incomes;
  final List<Friend> _friends;
  final List<BillSplit> _splits;
  DateTime _challengeStart;

  /// An Apple Pay purchase waiting to open in Quick Add. Set when a
  /// `runway://log` link arrives; Home picks it up once it's on screen.
  final pendingPurchase = ValueNotifier<ApplePayPurchase?>(null);

  UserProfile? _user;
  bool _needsSetup;
  bool _appLock;

  final _problems = StreamController<SaveProblem>.broadcast();
  int _pendingWrites = 0;

  /// The end of the line of saves; see [_persist].
  Future<void> _lastWrite = Future.value();
  bool _resyncNeeded = false;
  bool _disposed = false;

  /// Fires when a change couldn't be saved; the app shows a message.
  Stream<SaveProblem> get problems => _problems.stream;
  late RunwaySnapshot _snapshot;
  late int _streak;

  DateTime get today => dateOnly(_clock());

  /// The current time, from the same clock as everything else (tests fake it).
  DateTime get now => _clock();

  /// Ask for Face ID / passcode on launch and after time away.
  bool get appLockEnabled => _appLock;
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

  /// Repeating bills that are still going.
  List<RepeatingBill> get bills => List.unmodifiable(_bills);

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

  CoachGrounding get grounding =>
      CoachGrounding.fromSnapshot(_snapshot, period: _term.period);

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
    _persist(() => _repo.addExpense(expense));
  }

  /// Replaces the expense with the same id (amount, category, need, note).
  void updateExpense(Expense expense) {
    _checkAmount(expense.amount);
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index < 0) return;
    _expenses[index] = expense;
    _changed();
    _persist(() => _repo.updateExpense(expense));
  }

  /// Removes the expense and returns it, so the caller can offer Undo
  /// through [restoreExpense]. Null if it's already gone.
  Expense? deleteExpense(String id) {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index < 0) return null;
    final removed = _expenses.removeAt(index);
    _changed();
    _persist(() => _repo.deleteExpense(id));
    return removed;
  }

  void restoreExpense(Expense expense) {
    if (_expenses.any((e) => e.id == expense.id)) return;
    _expenses.add(expense);
    _changed();
    _persist(() => _repo.restoreExpense(expense.id));
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
    _persist(() => _repo.splitBill(added, myShare));
  }

  void settleSplit(String id) {
    _splits.removeWhere((s) => s.id == id);
    notifyListeners();
    _persist(() => _repo.settleSplit(id));
  }

  void signedIn(UserProfile user) {
    _user = user;
    notifyListeners();
    _persist(() => _repo.setCurrentUser(user));
  }

  /// Changes the name shown in the greeting.
  void rename(String name) {
    final user = _user;
    final trimmed = name.trim();
    if (user == null || validateName(trimmed) != null) return;
    _user = UserProfile(name: trimmed, email: user.email);
    notifyListeners();
    _persist(() => _repo.setCurrentUser(_user));
  }

  /// Turns the Face ID / passcode lock on or off. Callers verify the owner
  /// with [deviceAuth] first.
  void setAppLock(bool on) {
    if (on == _appLock) return;
    _appLock = on;
    notifyListeners();
    _persist(() => _repo.setAppLock(on));
  }

  void updateTerm(Term term) {
    if (term.name.trim().isEmpty ||
        !term.end.isAfter(term.start) ||
        !term.startingBalance.isFinite ||
        term.startingBalance < 0) {
      throw ArgumentError.value(term, 'term', 'invalid name, dates or balance');
    }
    // A longer term reserves the repeating bills for the days it gained.
    final added = term.end.isAfter(_term.end)
        ? _billsDue(from: _dayAfter(_term.end), to: term.end)
        : <UpcomingCost>[];
    _term = term;
    _upcoming.addAll(added);
    _changed();
    _persist(() => _repo.saveTerm(term, added: added));
  }

  /// With [monthly], [cost] is the first month of a repeating bill, and
  /// every month of it due before the term ends is reserved.
  void addUpcomingCost(UpcomingCost cost, {bool monthly = false}) {
    _checkAmount(cost.amount);
    if (!monthly) {
      _upcoming.add(cost);
      _changed();
      _persist(() => _repo.addUpcomingCost(cost));
      return;
    }
    final bill = RepeatingBill(
      id: 'b${DateTime.now().microsecondsSinceEpoch}',
      emoji: cost.emoji,
      name: cost.name,
      amount: cost.amount,
      firstDue: dateOnly(cost.dueDate),
    );
    final due = billsDue(bill, from: bill.firstDue, to: _term.end);
    _bills.add(bill);
    _upcoming.addAll(due);
    _changed();
    _persist(() => _repo.addBill(bill, due));
  }

  /// A one-off cost's new name, amount or due date.
  void updateUpcomingCost(UpcomingCost cost) {
    _checkAmount(cost.amount);
    final index = _upcoming.indexWhere((c) => c.id == cost.id);
    if (index < 0) return;
    _upcoming[index] = cost;
    _changed();
    _persist(() => _repo.updateUpcomingCost(cost));
  }

  /// A monthly bill's new name and amount, for the month due on [from] and
  /// every later one. Earlier months, paid or not, stay as they were.
  void updateBill(
    String billId, {
    required String name,
    required double amount,
    required DateTime from,
  }) {
    _checkAmount(amount);
    final index = _bills.indexWhere((b) => b.id == billId);
    if (index < 0) return;
    final bill = _bills[index].copyWith(name: name.trim(), amount: amount);
    _bills[index] = bill;
    for (var i = 0; i < _upcoming.length; i++) {
      final c = _upcoming[i];
      if (c.billId == billId && !c.dueDate.isBefore(from)) {
        _upcoming[i] = c.copyWith(name: bill.name, amount: amount);
      }
    }
    _changed();
    _persist(() => _repo.updateBill(bill, from: from));
  }

  /// Renames money coming in or changes its amount; [date] moves a payment
  /// that hasn't arrived yet. Money already received never changes: once
  /// repeating pay has paid out, a new amount stops it today and carries
  /// on from its next payday. A stopped payment is finished, so a new
  /// amount there corrects all of its paydays.
  void updateIncome(
    String id, {
    required String name,
    required double amount,
    DateTime? date,
  }) {
    _checkAmount(amount);
    final index = _incomes.indexWhere((i) => i.id == id);
    if (index < 0) return;
    final old = _incomes[index];
    final next = incomeChangeStarts(old, amount);
    if (next == null) {
      final edited = old.copyWith(
        name: name.trim(),
        amount: amount,
        firstDate: old.firstDate.isAfter(today) && date != null
            ? dateOnly(date)
            : null,
      );
      _incomes[index] = edited;
      _changed();
      _persist(() => _repo.updateIncome(edited));
      return;
    }
    final stopped = old.copyWith(name: name.trim(), endsOn: today);
    final continued = Income(
      id: 'i${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      amount: amount,
      frequency: old.frequency,
      firstDate: next,
    );
    _incomes[index] = stopped;
    _incomes.add(continued);
    _changed();
    _persist(() => _repo.updateIncome(stopped, continuedBy: continued));
  }

  /// When a new [amount] for [income] would start: its next payday, if it
  /// repeats, has already paid out and is still going. Null means the
  /// change applies to the whole payment instead.
  DateTime? incomeChangeStarts(Income income, double amount) {
    if (amount == income.amount ||
        !income.repeats ||
        income.endsOn != null ||
        income.firstDate.isAfter(today)) {
      return null;
    }
    return paydayAfter(income, today);
  }

  /// With [andLater], a repeating bill stops: this month and every later
  /// one is removed, and no new months are reserved.
  void deleteUpcomingCost(String id, {bool andLater = false}) {
    final cost = _upcoming.where((c) => c.id == id).firstOrNull;
    if (cost == null) return;
    final billId = cost.billId;
    if (andLater && billId != null) {
      _bills.removeWhere((b) => b.id == billId);
      _upcoming.removeWhere(
        (c) => c.billId == billId && !c.dueDate.isBefore(cost.dueDate),
      );
      _changed();
      _persist(() => _repo.stopBill(billId, from: cost.dueDate));
      return;
    }
    _upcoming.remove(cost);
    _changed();
    _persist(() => _repo.deleteUpcomingCost(id));
  }

  /// Every month of the repeating bills due from [from] to [to].
  List<UpcomingCost> _billsDue({
    required DateTime from,
    required DateTime to,
  }) => [for (final b in _bills) ...billsDue(b, from: from, to: to)];

  static DateTime _dayAfter(DateTime d) => DateTime(d.year, d.month, d.day + 1);

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
    _persist(() => _repo.payUpcomingCost(id, expense));
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
    _persist(() => _repo.addIncome(income));
  }

  /// No more paydays after today; the ones already received still count.
  void stopIncome(String id) {
    final index = _incomes.indexWhere((i) => i.id == id);
    if (index < 0) return;
    final endsOn = today;
    _incomes[index] = _incomes[index].copyWith(endsOn: endsOn);
    _changed();
    _persist(() => _repo.stopIncome(id, endsOn));
  }

  /// Removes the income and every payment it brought in.
  void deleteIncome(String id) {
    _incomes.removeWhere((i) => i.id == id);
    _changed();
    _persist(() => _repo.deleteIncome(id));
  }

  /// Swaps the demo term for the user's own, starting with no expenses.
  /// Repeating bills stop; add them again with [addUpcomingCost].
  void startTerm(Term term, List<UpcomingCost> upcoming) {
    _term = term;
    _bills.clear();
    _expenses.clear();
    _upcoming
      ..clear()
      ..addAll(upcoming);
    _incomes.clear();
    _needsSetup = false;
    _changed();
    _persist(() => _repo.startTerm(term, upcoming));
  }

  /// A monthly budget whose month has ended moves on to the current month.
  /// Expenses stay with the old month; leftover money, unpaid costs and pay
  /// that keeps coming carry over, and the new month's repeating bills are
  /// reserved. Money overspent is reserved as a cost due on day one, so it's
  /// covered before anything else.
  void startNewMonthIfDue() {
    if (_needsSetup) return;
    final next = nextMonth(
      term: _term,
      expenses: _expenses,
      incomes: _incomes,
      today: today,
    );
    if (next == null) return;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final incomes = [
      for (final (n, i) in continuingIncomes(_incomes, _term.end).indexed)
        i.copyWith(id: 'i$stamp-$n'),
    ];
    final added = [
      if (next.overspent > 0)
        UpcomingCost(
          id: 'u$stamp',
          emoji: '↩️',
          name: 'Overspent in ${monthName(_term.start)}',
          amount: next.overspent,
          dueDate: next.term.start,
        ),
      // Months skipped while the app was closed too: unpaid until marked.
      ..._billsDue(from: _dayAfter(_term.end), to: next.term.end),
    ];
    _term = next.term;
    _expenses.clear();
    _upcoming.addAll(added);
    _replace(_incomes, incomes);
    _changed();
    _persist(
      () => _repo.startNewMonth(next.term, incomes: incomes, added: added),
    );
  }

  /// Finished terms and months, newest first, read from storage once the
  /// saves already in line are done (so a month that just ended is there).
  Future<List<PastTerm>> history() async {
    await _lastWrite;
    return _repo.history();
  }

  /// Deletes everything on this device and signs out. Unlike other writes
  /// this waits for the database, so nothing is left behind if it fails.
  Future<void> eraseEverything() async {
    await _repo.eraseEverything();
    _apply(await _repo.load());
    _user = null;
    _changed();
  }

  /// Replaces everything in memory with what was loaded from storage.
  void _apply(BudgetData data) {
    _term = data.term;
    _replace(_expenses, data.expenses);
    _replace(_upcoming, data.upcoming);
    _replace(_bills, data.bills);
    _replace(_incomes, data.incomes);
    _replace(_friends, data.friends);
    _replace(_splits, data.splits);
    _challengeStart = data.challengeStart;
    _needsSetup = data.needsSetup;
    _appLock = data.appLock;
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

  /// Saves without blocking the UI: the screen has already changed, and
  /// the database catches up in the background.
  ///
  /// If a save fails, the screen would be showing something that isn't
  /// stored. So once every save in flight has finished, everything is
  /// reloaded from the database (the source of truth) and [problems] tells
  /// the user their change didn't stick.
  ///
  /// Saves run one at a time, in the order they were made: a save that
  /// looks something up first (like adding a bill right after setup) can't
  /// be overtaken by the next one.
  void _persist(Future<void> Function() write) {
    _pendingWrites++;
    _lastWrite = _lastWrite
        .then((_) => write())
        .then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            _report(error, stack, 'while saving to the database');
            _resyncNeeded = true;
          },
        )
        .whenComplete(() {
          _pendingWrites--;
          if (_pendingWrites == 0 && _resyncNeeded) unawaited(_resync());
        });
  }

  Future<void> _resync() async {
    _resyncNeeded = false;
    try {
      final data = await _repo.load();
      final user = await _repo.currentUser();
      // Newer changes started while loading; their saves would be missing
      // from what we just read. Try again once they've finished.
      if (_pendingWrites > 0) {
        _resyncNeeded = true;
        return;
      }
      if (_disposed) return;
      _apply(data);
      _user = user;
      _changed();
      _problems.add(SaveProblem.undone);
    } on Object catch (error, stack) {
      _report(error, stack, 'while reloading after a failed save');
      if (!_disposed) _problems.add(SaveProblem.unreadable);
    }
  }

  static void _report(Object error, StackTrace stack, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'runway storage',
        context: ErrorDescription(context),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_problems.close());
    super.dispose();
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

/// What went wrong when saving, worded for the person using the app.
enum SaveProblem {
  /// A change didn't save, so the screen went back to what's stored.
  undone('Couldn\'t save your last change, so it was undone. Try again.'),

  /// Saving failed and reading the data back failed too.
  unreadable('Couldn\'t save or reload your data. Close and reopen Runway.');

  const SaveProblem(this.message);
  final String message;
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
