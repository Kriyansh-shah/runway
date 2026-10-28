import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'auth.dart';
import 'budget_math.dart';
import 'budget_math.dart' as budget show nextIncome, savingsStreak;
import 'budget_sync.dart';
import 'coach.dart';
import 'device_auth.dart';
import 'format.dart';
import 'models.dart';
import 'purchase_link.dart';
import 'reminders.dart';
import 'repository.dart';
import 'spending_lookup.dart';
import 'spoken_expense.dart';
import 'split_math.dart';
import 'squad.dart';
import 'voice_inbox.dart';
import 'week_recap.dart';

/// Single source of truth for the app. Derived numbers are cached and
/// recomputed only when the underlying data changes.
class AppState extends ChangeNotifier {
  AppState({
    required BudgetRepository repository,
    required BudgetData data,
    this.coach = const LocalCoach(),
    this.deviceAuth = const LocalDeviceAuth(),
    this.accounts = const NoAccounts(),
    this.squadService = const NoSquad(),
    this.reminderScheduler = const NoReminders(),
    BudgetBackupStore budgetBackups = const NoBudgetBackups(),
    LocalSyncStore? syncStore,
    BudgetCipher budgetCipher = const BudgetCipher(),
    UserProfile? user,
    DateTime Function()? clock,
  }) : _repo = repository,
       _clock = clock ?? DateTime.now,
       _term = data.term,
       _expenses = [...data.expenses],
       _upcoming = [...data.upcoming],
       _bills = [...data.bills],
       _incomes = [...data.incomes],
       _customCategories = [...data.customCategories],
       _friends = [...data.friends],
       _splits = [...data.splits],
       _needsSetup = data.needsSetup,
       _savingsHistory = [...data.savingsHistory],
       _savingsAsked = data.savingsAsked,
       _jars = [...data.jars],
       _jarDeposits = [...data.jarDeposits],
       _reminders = data.reminders,
       _appLock = data.appLock,
       _challengeStart = data.challengeStart {
    _user = user;
    _recompute();
    sync = BudgetSyncController(
      store: budgetBackups,
      local: syncStore ?? MemorySyncStore(),
      exportBudget: () async {
        await _lastWrite;
        return _repo.exportSnapshot();
      },
      importBudget: _importBudget,
      userId: () => account?.id,
      cipher: budgetCipher,
    )..addListener(notifyListeners);
  }

  /// Encrypted budget sync across the person's signed-in devices.
  late final BudgetSyncController sync;

  /// Replaces everything with a budget synced from another device.
  Future<void> _importBudget(Map<String, Object?> snapshot) async {
    await _lastWrite;
    await _repo.importSnapshot(snapshot);
    _apply(await _repo.load());
    _changed();
  }

  final BudgetRepository _repo;
  final DateTime Function() _clock;
  final AffordabilityCoach coach;

  /// Face ID / Touch ID / passcode prompt for the app lock.
  final DeviceAuth deviceAuth;

  /// Optional Google sign-in (Supabase). [NoAccounts] where it isn't set up.
  final AccountService accounts;

  /// Real squads on the server. [NoSquad] shows sample friends instead.
  final SquadService squadService;

  SocialData? _social;
  String? _selectedSquadId;
  Map<String, Map<String?, int>> _byScope = const {};
  bool _squadLoading = false;
  String? _squadError;

  Term _term;
  final List<Expense> _expenses;
  final List<UpcomingCost> _upcoming;
  final List<RepeatingBill> _bills;
  final List<Income> _incomes;
  final List<CustomCategory> _customCategories;
  final List<Friend> _friends;
  final List<BillSplit> _splits;
  DateTime _challengeStart;

  /// An Apple Pay purchase waiting to open in Quick Add. Set when a
  /// `runway://log` link arrives; Home picks it up once it's on screen.
  final pendingPurchase = ValueNotifier<ApplePayPurchase?>(null);

  /// Set by the "Log by voice" home-screen shortcut; the shell opens Quick
  /// Add listening and clears it.
  final voiceAddRequested = ValueNotifier<bool>(false);

  /// Set by tapping the evening check-in; the shell opens Quick Add and
  /// clears it.
  final quickAddRequested = ValueNotifier<bool>(false);

  /// Set when the first big cost is added and bill reminders are off; the
  /// shell offers to turn them on and clears it.
  final offerBillReminders = ValueNotifier<bool>(false);

  /// Expenses just filed from Siri, for a "Added from Siri" note; the app
  /// shows it and clears this.
  final addedFromSiri = ValueNotifier<List<Expense>?>(null);

  /// A term or month that just ended, waiting for its recap. Set by
  /// [checkForRecap]; the shell shows it once Home is on screen.
  final pendingRecap = ValueNotifier<Recap?>(null);

  /// A tab another screen wants shown (0 Home, 1 Savings, 2 Coach,
  /// 3 Squad); the shell switches to it and clears this.
  final requestedTab = ValueNotifier<int?>(null);

  /// When the last offered recap's term ended, so it's offered only once.
  DateTime? _recapOffered;

  UserProfile? _user;
  bool _needsSetup;
  bool _appLock;
  final List<SavedTerm> _savingsHistory;
  bool _savingsAsked;
  final List<SavingsJar> _jars;

  /// Every jar deposit, open jars or not, for this term's numbers.
  final List<JarDeposit> _jarDeposits;

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

  /// Finished terms and months, newest first, with what each one saved.
  List<SavedTerm> get savingsHistory => List.unmodifiable(_savingsHistory);

  /// Everything saved in finished terms and months. This term's goal
  /// joins it when the term ends.
  double get totalSaved => _savingsHistory.fold(0, (s, t) => s + t.saved);

  /// Terms or months in a row that hit their savings goal.
  int get savingsStreak => budget.savingsStreak(_savingsHistory);

  /// Home offers to set a savings goal: there's none yet, and the person
  /// hasn't been asked (people set up before savings existed).
  bool get offerSavingsGoal =>
      !_needsSetup && !_savingsAsked && _term.savingsGoal == 0;

  /// The numbers as they'd be with [goal] as the savings goal, to preview
  /// a change before saving it.
  RunwaySnapshot snapshotWithGoal(double goal) => computeRunway(
    term: _term.copyWith(savingsGoal: goal),
    expenses: _expenses,
    upcoming: _upcoming,
    incomes: _incomes,
    jarDeposits: _jarDeposits,
    today: today,
  );

  /// Sets this term's savings goal (0 for none), from today on. It can't
  /// be more than the money not already set aside for big costs.
  void setSavingsGoal(double goal) {
    if (!goal.isFinite || goal < 0) {
      throw ArgumentError.value(goal, 'goal', 'must be 0 or more');
    }
    final capped = math.min(goal, _snapshot.maxSavingsGoal);
    _term = _term.copyWith(savingsGoal: (capped * 100).round() / 100);
    final asked = _savingsAsked;
    _savingsAsked = true;
    _changed();
    final term = _term;
    _persist(() async {
      await _repo.saveTerm(term);
      if (!asked) await _repo.setSavingsAsked();
    });
  }

  /// What the person is saving up for, oldest first.
  List<SavingsJar> get jars => List.unmodifiable(_jars);

  SavingsJar? jar(String id) => _jars.where((j) => j.id == id).firstOrNull;

  /// Money put into (or taken out of) jars that are still open, newest
  /// first, for Home's Recent list next to expenses.
  List<({JarDeposit deposit, SavingsJar jar})> recentJarDeposits([
    int count = 6,
  ]) => [
    for (final jar in _jars)
      for (final d in jar.deposits)
        if (!dateOnly(d.date).isBefore(dateOnly(_term.start)))
          (deposit: d, jar: jar),
  ]..sort((a, b) => b.deposit.date.compareTo(a.deposit.date));

  /// Starts saving up for [name], which costs [target]. Nothing is set
  /// aside until money is put in.
  SavingsJar startJar({required String name, required double target}) {
    _checkAmount(target);
    var clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) throw ArgumentError.value(name, 'name', 'is empty');
    if (clean.length > 40) clean = clean.substring(0, 40).trim();
    final jar = SavingsJar(
      id: 'j${DateTime.now().microsecondsSinceEpoch}',
      name: '${clean[0].toUpperCase()}${clean.substring(1)}',
      target: _roundCents(target),
      createdAt: _clock(),
    );
    _jars.add(jar);
    _changed();
    _persist(() => _repo.addJar(jar));
    return jar;
  }

  /// The most that can go into [jar] now: what it still needs, and no more
  /// than the spending money there is.
  double maxJarDeposit(SavingsJar jar) =>
      _roundCents(math.max(0, math.min(jar.remaining, _snapshot.available)));

  /// A friendly amount to put into [jar] today: about a fifth of the daily
  /// allowance, never more than [maxJarDeposit]. 0 when nothing can go in.
  double suggestedJarDeposit(SavingsJar jar) {
    final max = maxJarDeposit(jar);
    final plan = SavingsPlan.forShare(jar.remaining, grounding, 0.2);
    return plan == null ? 0 : math.min(plan.perDay, max);
  }

  /// Moves [amount] of spending money into a jar (capped at
  /// [maxJarDeposit]). It stays set aside until the jar is bought or
  /// dropped, across months and terms.
  void putIntoJar(String jarId, double amount) {
    _checkAmount(amount);
    final i = _jars.indexWhere((j) => j.id == jarId);
    if (i < 0) return;
    final moved = math.min(_roundCents(amount), maxJarDeposit(_jars[i]));
    if (moved <= 0) return;
    _addJarDeposit(i, moved);
  }

  /// Takes [amount] back out of a jar (at most what's in it) and makes it
  /// spending money again. Taken out the same day it went in, today's
  /// safe-to-spend gets it all back; money saved on earlier days spreads
  /// over the days left, like any money coming in.
  void takeOutOfJar(String jarId, double amount) {
    _checkAmount(amount);
    final i = _jars.indexWhere((j) => j.id == jarId);
    if (i < 0) return;
    final taken = math.min(_roundCents(amount), _roundCents(_jars[i].saved));
    if (taken <= 0) return;
    _addJarDeposit(i, -taken);
  }

  /// Money in (positive) or out (negative) of the jar at [i].
  void _addJarDeposit(int i, double amount) {
    final deposit = JarDeposit(
      id: 'jd${DateTime.now().microsecondsSinceEpoch}',
      jarId: _jars[i].id,
      amount: amount,
      date: _clock(),
    );
    _jars[i] = _jars[i].withDeposit(deposit);
    _jarDeposits.add(deposit);
    _changed();
    _persist(() => _repo.addJarDeposit(deposit));
  }

  /// Bought it: the jar's money comes back and pays for it, logged as a
  /// planned Shopping expense. If it wasn't full, the rest comes out of
  /// spending money.
  void buyJar(String jarId) => _endJar(jarId, bought: true);

  /// Not saving for it any more: its money goes back to spending.
  void dropJar(String jarId) => _endJar(jarId, bought: false);

  void _endJar(String jarId, {required bool bought}) {
    final i = _jars.indexWhere((j) => j.id == jarId);
    if (i < 0) return;
    final jar = _jars.removeAt(i);
    final takenOut = JarDeposit(
      id: 'jd${DateTime.now().microsecondsSinceEpoch}',
      jarId: jarId,
      amount: -jar.saved,
      date: _clock(),
    );
    if (jar.saved != 0) _jarDeposits.add(takenOut);
    final purchase = bought
        ? _newExpense(
            jar.target,
            ExpenseCategory.shopping,
            false,
            jar.name,
            planned: true,
          )
        : null;
    if (purchase != null) _expenses.add(purchase);
    _changed();
    _persist(
      () => _repo.endJar(
        jarId,
        bought: bought,
        takenOut: takenOut,
        purchase: purchase,
      ),
    );
  }

  static double _roundCents(double v) => (v * 100).round() / 100;

  /// "Not now" on Home's savings card: it won't ask again.
  void skipSavingsGoal() {
    if (_savingsAsked) return;
    _savingsAsked = true;
    notifyListeners();
    _persist(_repo.setSavingsAsked);
  }

  Term get term => _term;
  RunwaySnapshot get snapshot => _snapshot;
  int get streak => _streak;
  PetMood get mood => moodFor(_snapshot);
  PetLevel get petLevel => PetLevel.fromStreak(_streak);
  NeedWantSplit get thisWeek => weekSplit(_expenses, today);

  /// What Siri needs to answer "how much can I spend today?" without
  /// opening the app (see ios/Runner/VoiceLog.swift). Null before setup.
  /// Days are local "yyyy-mm-dd" keys, so Siri can tell if it's stale.
  Map<String, Object?>? get siriSummary {
    if (_needsSetup) return null;
    final s = _snapshot;
    final now = today;
    String key(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final days = <String, double>{};
    final byCategory = <CategoryRef, double>{};
    for (final e in _expenses) {
      final age = daysBetween(e.date, now);
      if (age < 0 || age > 6) continue;
      days.update(key(e.date), (v) => v + e.amount, ifAbsent: () => e.amount);
      byCategory.update(
        e.filedUnder,
        (v) => v + e.amount,
        ifAbsent: () => e.amount,
      );
    }
    final top = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {
      'day': key(now),
      'period': _term.period.noun,
      'termEnd': key(_term.end),
      'available': _roundCents(s.available),
      'spentToday': _roundCents(s.usedTodayAmount),
      'daysLeft': s.daysLeft,
      'allowance': _roundCents(s.dailyAllowance),
      'safeToday': _roundCents(s.safeToSpendToday),
      'savingsGoal': _roundCents(s.savingsGoal),
      'onTrack': s.tooEarlyToForecast ? null : s.onTrackToSave,
      'runsOut': s.covered || s.runwayDate == null ? null : key(s.runwayDate!),
      'days': days.map((k, v) => MapEntry(k, _roundCents(v))),
      'weekTop': [
        for (final e in top.take(2))
          {
            'label': e.key.label,
            'emoji': e.key.emoji,
            'amount': _roundCents(e.value),
          },
      ],
      'categories': [for (final c in _customCategories) c.name],
    };
  }

  /// Sample friends for Squad's preview (macOS, tests). With real squads
  /// see [splitPeople] and [squad].
  List<Friend> get friends => List.unmodifiable(_friends);

  /// IOUs, newest first. With real squads the sample IOUs seeded on first
  /// launch ("Aarav owes you…") are left out: those people don't exist.
  List<BillSplit> get splits => List.unmodifiable(
    realSquad ? _splits.where((s) => !_sampleSplitIds.contains(s.id)) : _splits,
  );

  static const _sampleSplitIds = {'pizza', 'wifi'};

  /// Who a bill can be split with when Squad isn't real: the sample
  /// friends (IOUs stay on the phone). With real squads see [friendPeople].
  List<Friend> get splitPeople => realSquad ? const [] : friends;

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

  /// This term day by day, up to today. See [dailyLedger].
  List<DayLedger> get ledger => dailyLedger(
    term: _term,
    expenses: _expenses,
    upcoming: _upcoming,
    incomes: _incomes,
    jarDeposits: _jarDeposits,
    today: today,
  );

  /// Everything logged on [day], earliest first.
  List<Expense> expensesOn(DateTime day) => [
    for (final e in _expenses)
      if (sameDay(e.date, day)) e,
  ]..sort((a, b) => a.date.compareTo(b.date));

  /// The person's own categories, most recently used first.
  List<CustomCategory> get customCategories =>
      List.unmodifiable(_customCategories);

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

  CoachGrounding get grounding {
    final totals = <String, double>{};
    for (final e in _expenses) {
      final label = e.filedUnder.label;
      totals[label] = (totals[label] ?? 0) + e.amount;
    }
    final byCategory = [
      for (final MapEntry(:key, :value) in totals.entries)
        (category: key, spent: value),
    ]..sort((a, b) => b.spent.compareTo(a.spent));
    return CoachGrounding.fromSnapshot(
      _snapshot,
      period: _term.period,
      byCategory: byCategory,
      savingFor: [
        for (final j in _jars) (name: j.name, saved: j.saved, target: j.target),
      ],
      history: SpendingHistory(
        expenses: List.unmodifiable(_expenses),
        ledger: ledger,
        today: today,
        termStart: _term.start,
      ),
    );
  }

  /// Updates the screen immediately, then saves in the background.
  /// With [custom], the expense is filed under it (and [category] is Other).
  void addExpense({
    required double amount,
    required ExpenseCategory category,
    required bool isNeed,
    String? note,
    CustomCategory? custom,
  }) {
    _checkAmount(amount);
    final expense = _newExpense(
      amount,
      custom == null ? category : ExpenseCategory.other,
      isNeed,
      note,
      custom: custom,
    );
    _expenses.add(expense);
    if (custom != null) _moveToFront(custom.id);
    _changed();
    _persist(() => _repo.addExpense(expense));
  }

  /// Files what was said to Siri like Quick Adds: a category guessed from
  /// what it was for, at the time it was said (or now, if that was before
  /// this term began). Waits in the inbox until setup is done.
  void addSpokenExpenses(List<VoiceEntry> entries) {
    final added = <Expense>[];
    final stamp = DateTime.now().microsecondsSinceEpoch;
    for (final (i, entry) in entries.indexed) {
      if (!entry.amount.isFinite ||
          entry.amount <= 0 ||
          entry.amount >= 1000000) {
        continue;
      }
      // "8 bucks on coffee" → "Coffee". A category said to Siri wins over
      // a guess, but your own category still wins if it's named.
      final note = SpokenExpense.parse(entry.what).note;
      final said = ExpenseCategory.values.asNameMap()[entry.category];
      final own = _customCategories
          .where((c) => c.name.toLowerCase() == entry.custom?.toLowerCase())
          .firstOrNull;
      final guess = own != null
          ? CategoryRef(ExpenseCategory.other, own)
          : SpokenExpense.guessCategory(note, _customCategories);
      final filed = guess?.custom != null || said == null
          ? guess ?? const CategoryRef(ExpenseCategory.other)
          : CategoryRef(said);
      final expense = Expense(
        id: 'e${stamp}s$i',
        amount: _roundCents(entry.amount),
        category: filed.category,
        custom: filed.custom,
        isNeed: SpokenExpense.isNeed(filed.category),
        date: entry.at.isBefore(_term.start) || entry.at.isAfter(_clock())
            ? _clock()
            : entry.at,
        note: note,
      );
      _expenses.add(expense);
      if (filed.custom case final c?) _moveToFront(c.id);
      added.add(expense);
    }
    if (added.isEmpty) return;
    _changed();
    for (final e in added) {
      _persist(() => _repo.addExpense(e));
    }
    addedFromSiri.value = added;
  }

  /// Why [name] can't be a new category (or [editingId]'s new name), or
  /// null if it can.
  String? checkCategoryName(String name, {String? editingId}) {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return 'Give it a name';
    if (key.length > maxCategoryName) {
      return 'Keep it to $maxCategoryName letters';
    }
    final taken =
        ExpenseCategory.values.any((c) => c.label.toLowerCase() == key) ||
        _customCategories.any(
          (c) => c.id != editingId && c.name.toLowerCase() == key,
        );
    return taken ? 'There\'s already a ${name.trim()} category' : null;
  }

  static const maxCategoryName = 20;

  /// The name to offer as a new category when an Other expense is noted
  /// [note]: it has been logged in Other with the same note before (any
  /// capitals), and isn't a category yet. Null if there's nothing to offer.
  String? categorySuggestion(String note) {
    final name = note.trim();
    final key = name.toLowerCase();
    if (checkCategoryName(name) != null) return null;
    final seen = _expenses.any(
      (e) =>
          e.category == ExpenseCategory.other &&
          e.custom == null &&
          e.note?.trim().toLowerCase() == key,
    );
    if (!seen) return null;
    final first = name.characters.first;
    return first.toUpperCase() + name.substring(first.length);
  }

  /// Makes a category and returns it. Expenses already in Other with its
  /// name as their note move into it, so its totals start out right.
  CustomCategory addCustomCategory({
    required String name,
    required String emoji,
  }) {
    final trimmed = name.trim();
    if (checkCategoryName(trimmed) != null || emoji.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'invalid category name');
    }
    final category = CustomCategory(
      id: 'c${DateTime.now().microsecondsSinceEpoch}',
      emoji: emoji.trim().characters.first,
      name: trimmed,
    );
    _customCategories.insert(0, category);
    final key = trimmed.toLowerCase();
    final moved = <Expense>[];
    for (var i = 0; i < _expenses.length; i++) {
      final e = _expenses[i];
      if (e.category == ExpenseCategory.other &&
          e.custom == null &&
          e.note?.trim().toLowerCase() == key) {
        _expenses[i] = e.copyWith(custom: () => category);
        moved.add(_expenses[i]);
      }
    }
    _changed();
    _persist(() async {
      await _repo.addCustomCategory(category);
      for (final e in moved) {
        await _repo.updateExpense(e);
      }
    });
    return category;
  }

  /// A new name or emoji for a custom category, everywhere it's shown.
  void updateCustomCategory(CustomCategory category) {
    final index = _customCategories.indexWhere((c) => c.id == category.id);
    if (index < 0 ||
        checkCategoryName(category.name, editingId: category.id) != null) {
      return;
    }
    final updated = category.copyWith(
      name: category.name.trim(),
      emoji: category.emoji.trim().characters.first,
    );
    _customCategories[index] = updated;
    for (var i = 0; i < _expenses.length; i++) {
      if (_expenses[i].custom?.id == updated.id) {
        _expenses[i] = _expenses[i].copyWith(custom: () => updated);
      }
    }
    _changed();
    _persist(() => _repo.updateCustomCategory(updated));
  }

  /// Removes a custom category. Its expenses stay, filed under Other, and
  /// ones without a note keep its name as their note.
  void deleteCustomCategory(String id) {
    final index = _customCategories.indexWhere((c) => c.id == id);
    if (index < 0) return;
    final removed = _customCategories.removeAt(index);
    for (var i = 0; i < _expenses.length; i++) {
      final e = _expenses[i];
      if (e.custom?.id != id) continue;
      _expenses[i] = e.copyWith(
        note: () => e.note ?? removed.name,
        custom: () => null,
      );
    }
    _changed();
    _persist(() => _repo.deleteCustomCategory(id));
  }

  /// What's left of the savings goal if the term ended now, in cents.
  double get _keptSavings => (_snapshot.savingsKept * 100).round() / 100;

  /// Money that would carry on if the term ended now: everything but the
  /// savings it keeps. Offered as the next semester's starting money.
  double get leftIfEndedNow =>
      math.max(0, ((_snapshot.balance - _keptSavings) * 100).round() / 100);

  static SavedTerm _savedTerm(Term term, double saved) => SavedTerm(
    name: term.name,
    period: term.period,
    goal: term.savingsGoal,
    saved: saved,
  );

  void _moveToFront(String customId) {
    final index = _customCategories.indexWhere((c) => c.id == customId);
    if (index > 0) {
      _customCategories.insert(0, _customCategories.removeAt(index));
    }
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
    CustomCategory? custom,
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
    final myShare = _newExpense(
      shares.mine,
      custom == null ? category : ExpenseCategory.other,
      isNeed,
      description,
      custom: custom,
    );
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
    _persist(() => _repo.setCurrentUser(user), budget: false);
  }

  /// Squad with real friends is possible here (sign-in is set up), even if
  /// the person hasn't signed in yet. Otherwise Squad shows sample friends.
  bool get realSquad => accounts.canUseGoogle || account != null;

  /// Your account ID with squads and friends loaded; null otherwise.
  String? get me => _social?.me;

  /// Every squad you're in, oldest first.
  List<Squad> get squads => _social?.squads ?? const [];

  /// The squad Squad's tab is showing: the one picked, else the first.
  Squad? get squad {
    final all = squads;
    if (all.isEmpty) return null;
    return all.firstWhere(
      (s) => s.id == _selectedSquadId,
      orElse: () => all.first,
    );
  }

  /// Shows [squadId]'s challenge and leaderboard.
  void selectSquad(String squadId) {
    if (_selectedSquadId == squadId) return;
    _selectedSquadId = squadId;
    notifyListeners();
  }

  /// Friends (squadmates and people added with a code), by name.
  List<Person> get friendPeople =>
      [...?_social?.friends]..sort((a, b) => a.name.compareTo(b.name));

  /// Anyone you know or have split with, by account ID.
  Person? person(String id) => _social?.people[id];

  /// The balance with each friend in cents: positive means they owe you.
  Map<String, int> get friendBalances => {
    for (final e in _byScope.entries)
      e.key: e.value.values.fold(0, (a, b) => a + b),
  }..removeWhere((_, v) => v == 0);

  /// Splits and settle-ups between you and [friendId], newest first.
  List<Object> activityWith(String friendId) {
    final social = _social;
    if (social == null) return const [];
    final items = <(DateTime, Object)>[
      for (final e in social.expenses)
        if (!e.deleted &&
            (e.shares.containsKey(friendId) || e.paidBy == friendId) &&
            (e.shares.containsKey(social.me) || e.paidBy == social.me))
          (e.createdAt, e),
      for (final s in social.settlements)
        if ({s.from, s.to}.containsAll({friendId, social.me})) (s.createdAt, s),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final i in items) i.$2];
  }

  /// The fewest payments that would settle [squad] (when it simplifies).
  List<SettlementItem> simplifiedPayments(Squad squad) {
    final social = _social;
    if (social == null) return const [];
    final net = <String, int>{};
    void add(String who, int cents) => net[who] = (net[who] ?? 0) + cents;
    for (final e in social.expenses) {
      if (e.deleted || e.squadId != squad.id) continue;
      for (final share in e.shares.entries) {
        if (share.key == e.paidBy) continue;
        add(e.paidBy, share.value);
        add(share.key, -share.value);
      }
    }
    for (final st in social.settlements) {
      if (st.squadId != squad.id) continue;
      add(st.from, st.amountCents);
      add(st.to, -st.amountCents);
    }
    return simplifyDebts(net, squadId: squad.id);
  }

  /// A squad request is on its way.
  bool get squadLoading => _squadLoading;

  /// Why the last squad refresh failed, if it did.
  String? get squadError => _squadError;

  SquadStats get _squadStats => SquadStats(
    name: _user?.name ?? 'Friend',
    streak: _streak,
    noDeliveryDays: myNoDeliveryDays,
  );

  /// Shares your streak and challenge dots, then loads squads, friends,
  /// splits and settle-ups. Errors end up in [squadError].
  Future<void> refreshSquad() async {
    if (account == null) {
      _setSocial(null);
      _squadError = null;
      notifyListeners();
      return;
    }
    await _squadCall(_reload);
  }

  Future<void> _reload() async =>
      _setSocial(await squadService.sync(_squadStats));

  void _setSocial(SocialData? social) {
    _social = social;
    _byScope = social == null
        ? const {}
        : balancesByScope(
            me: social.me,
            expenses: social.expenses,
            settlements: social.settlements,
            simplified: {
              for (final s in social.squads)
                if (s.simplifyDebts) s.id,
            },
          );
    if (social != null) unawaited(_bringInSplits(social));
  }

  /// Your part of each split from a friend becomes an expense in your
  /// budget (once: `sx-<split id>`), and leaves again if the split is
  /// deleted. Only for splits dated in this term.
  Future<void> _bringInSplits(SocialData social) async {
    final known = await _repo.sharedExpenseIds();
    if (_disposed) return;
    var changed = false;
    for (final e in social.expenses) {
      final id = sharedExpenseId(e.id);
      if (e.deleted) {
        if (_expenses.any((x) => x.id == id)) {
          deleteExpense(id);
          changed = true;
        }
        continue;
      }
      final mine = e.shares[social.me] ?? 0;
      final date = e.createdAt.toLocal();
      if (mine <= 0 ||
          known.contains(id) ||
          date.isBefore(_term.start) ||
          dateOnly(date).isAfter(_term.end)) {
        continue;
      }
      final expense = Expense(
        id: id,
        amount: mine / 100,
        category:
            ExpenseCategory.values.asNameMap()[e.category] ??
            ExpenseCategory.other,
        isNeed: true,
        date: date,
        note: e.description,
      );
      _expenses.add(expense);
      _persist(() => _repo.addExpense(expense));
      changed = true;
    }
    if (changed) _changed();
  }

  /// The local expense ID for your part of split [splitId].
  static String sharedExpenseId(String splitId) => 'sx-$splitId';

  /// Starts a squad and shows it. Throws [SquadException] when it fails.
  Future<void> createSquad(String name) => _squadCall(() async {
    _selectedSquadId = await squadService.create(name, _squadStats);
    await _reload();
  }, rethrowErrors: true);

  /// Joins with an invite code; false when the code doesn't work. Throws
  /// [SquadException] for other problems.
  Future<bool> joinSquad(String code) async {
    var joined = false;
    await _squadCall(() async {
      final id = await squadService.join(code, _squadStats);
      joined = id != null;
      if (id != null) {
        _selectedSquadId = id;
        await _reload();
      }
    }, rethrowErrors: true);
    return joined;
  }

  /// A code to share so friends can join the squad on screen.
  Future<String> squadInviteCode() {
    final squad = this.squad;
    if (squad == null) throw StateError('not in a squad');
    return squadService.inviteCode(squad.id);
  }

  /// Leaves the squad on screen.
  Future<void> leaveSquad() async {
    final squad = this.squad;
    if (squad == null) return;
    await _squadCall(() async {
      await squadService.leave(squad.id);
      _selectedSquadId = null;
      await _reload();
    }, rethrowErrors: true);
  }

  /// Turns "simplify debts" on or off for the squad on screen.
  Future<void> setSimplifyDebts(bool on) async {
    final squad = this.squad;
    if (squad == null) return;
    await _squadCall(() async {
      await squadService.setSimplifyDebts(squad.id, on);
      await _reload();
    }, rethrowErrors: true);
  }

  /// Your friend code, to share.
  Future<String> friendCode() => squadService.friendCode();

  /// Adds a friend by their code; false when it doesn't work.
  Future<bool> addFriend(String code) async {
    var added = false;
    await _squadCall(() async {
      added = await squadService.addFriend(code, _squadStats);
      if (added) await _reload();
    }, rethrowErrors: true);
    return added;
  }

  Future<void> removeFriend(String personId) => _squadCall(() async {
    await squadService.removeFriend(personId);
    await _reload();
  }, rethrowErrors: true);

  /// True when you can remove people from the squad on screen.
  bool get ownsSquad => me != null && squad?.ownerId == me;

  /// Removes [personId] from the squad on screen (you must own it). They
  /// can't rejoin it with an invite code.
  Future<void> removeFromSquad(String personId) async {
    final squad = this.squad;
    if (squad == null) return;
    await _squadCall(() async {
      await squadService.removeMember(squad.id, personId);
      await _reload();
    }, rethrowErrors: true);
  }

  /// Blocks [personId]: unfriends them and hides you from each other.
  Future<void> block(String personId) => _squadCall(() async {
    await squadService.block(personId);
    await _reload();
  }, rethrowErrors: true);

  Future<void> unblock(String personId) => _squadCall(() async {
    await squadService.unblock(personId);
    await _reload();
  }, rethrowErrors: true);

  /// The people you've blocked, for Settings.
  Future<List<Person>> blockedPeople() => squadService.blockedPeople();

  /// Reports a person, or a squad for its name. Throws [SquadException].
  Future<void> report({
    String? personId,
    String? squadId,
    required ReportReason reason,
    String? details,
  }) => squadService.report(
    personId: personId,
    squadId: squadId,
    reason: reason,
    details: details,
  );

  /// Splits [totalCents] between you and friends ([shares] by account ID,
  /// yours included, adding up to the total), paid by [paidBy]. Your part
  /// counts as spending whoever paid; their parts are what they owe the
  /// payer. Throws [SquadException].
  Future<void> splitWithFriends({
    required String description,
    required int totalCents,
    required String paidBy,
    required SplitKind kind,
    required Map<String, int> shares,
    required ExpenseCategory category,
    required bool isNeed,
    String? squadId,
    CustomCategory? custom,
  }) async {
    final me = this.me;
    if (me == null) {
      throw const SquadException('Sign in to split with friends.');
    }
    await _squadCall(() async {
      final id = await squadService.addSharedExpense(
        squadId: squadId,
        description: description,
        category: (custom == null ? category : ExpenseCategory.other).name,
        totalCents: totalCents,
        paidBy: paidBy,
        kind: kind,
        shares: shares,
      );
      final mine = shares[me] ?? 0;
      if (mine > 0) {
        final expense = Expense(
          id: sharedExpenseId(id),
          amount: mine / 100,
          category: custom == null ? category : ExpenseCategory.other,
          custom: custom,
          isNeed: isNeed,
          date: _clock(),
          note: description,
        );
        _expenses.add(expense);
        if (custom != null) _moveToFront(custom.id);
        _changed();
        _persist(() => _repo.addExpense(expense));
      }
      await _reload();
    }, rethrowErrors: true);
  }

  /// Deletes a split for everyone in it, and your part from your budget.
  Future<void> deleteSharedExpense(String splitId) => _squadCall(() async {
    await squadService.deleteSharedExpense(splitId);
    deleteExpense(sharedExpenseId(splitId));
    await _reload();
  }, rethrowErrors: true);

  /// Removes a settle-up for both people: what they owe each other goes
  /// back to how it was. The budget doesn't change.
  Future<void> deleteSettlement(String settlementId) => _squadCall(() async {
    await squadService.deleteSettlement(settlementId);
    await _reload();
  }, rethrowErrors: true);

  /// Records [amountCents] paid between you and [friendId] (whichever way
  /// it's owed); everything when null. Settle-ups don't touch the budget:
  /// the spending was counted when the split was added.
  Future<void> settleUpWith(String friendId, {int? amountCents}) async {
    final me = this.me;
    if (me == null) return;
    final items = settleUp(
      me: me,
      friend: friendId,
      byScope: _byScope[friendId] ?? const {},
      amountCents: amountCents,
    );
    if (items.isEmpty) return;
    await _squadCall(() async {
      await squadService.recordSettlements(items);
      await _reload();
    }, rethrowErrors: true);
  }

  /// IOUs with people who don't use Runway: they stay on this phone. You
  /// paid; [owed] is what each owes you. Your part was counted elsewhere
  /// (or is [myShare], counted here).
  void addLocalIous({
    required String description,
    required Map<String, double> owed,
    double myShare = 0,
    ExpenseCategory category = ExpenseCategory.other,
    CustomCategory? custom,
    bool isNeed = true,
  }) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final added = [
      for (final e in owed.entries)
        if (e.value > 0)
          BillSplit(
            id: 's$stamp-${e.key.toLowerCase()}',
            person: e.key,
            amount: e.value,
            note: description,
            theyOweYou: true,
          ),
    ];
    if (myShare <= 0) {
      if (added.isEmpty) return;
      _splits.insertAll(0, added);
      notifyListeners();
      for (final split in added) {
        _persist(() => _repo.splitBill([split], null));
      }
      return;
    }
    final share = _newExpense(
      myShare,
      custom == null ? category : ExpenseCategory.other,
      isNeed,
      description,
      custom: custom,
    );
    _splits.insertAll(0, added);
    _expenses.add(share);
    if (custom != null) _moveToFront(custom.id);
    _changed();
    _persist(() => _repo.splitBill(added, share));
  }

  Future<void> _squadCall(
    Future<void> Function() run, {
    bool rethrowErrors = false,
  }) async {
    _squadLoading = true;
    _squadError = null;
    notifyListeners();
    try {
      await run();
    } on SquadException catch (e) {
      if (rethrowErrors) rethrow;
      _squadError = e.message;
    } finally {
      _squadLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// The linked Google account, or null when it's name-only.
  Account? get account => accounts.current;

  /// Signs in with Google; false when the person backed out. From the
  /// welcome screen this also makes the profile, greeting them by their
  /// Google first name; afterwards the name they chose stays.
  Future<bool> signInWithGoogle() async {
    final account = await accounts.signInWithGoogle();
    if (account == null) return false;
    final name =
        _user?.name ??
        (validateName(account.firstName) == null
            ? account.firstName
            : 'Friend');
    _user = UserProfile(name: name, email: account.email);
    notifyListeners();
    _persist(() => _repo.setCurrentUser(_user), budget: false);
    unawaited(refreshSquad());
    await sync.check();
    return true;
  }

  /// Matches the profile to an account that's already signed in at launch:
  /// on the web, Google's redirect reloads the page signed in. Creates the
  /// profile from the Google name if there's none yet.
  void adoptSignedInAccount() {
    final account = this.account;
    if (account == null) return;
    final user = _user;
    if (user != null && user.email == account.email) return;
    final name =
        user?.name ??
        (validateName(account.firstName) == null
            ? account.firstName
            : 'Friend');
    _user = UserProfile(name: name, email: account.email);
    notifyListeners();
    _persist(() => _repo.setCurrentUser(_user), budget: false);
  }

  /// Unlinks the Google account on this phone. The budget stays.
  Future<void> signOutAccount() async {
    await accounts.signOut();
    _forgetAccount();
  }

  /// Deletes the Google-linked account on the server. The budget on this
  /// phone stays; "Erase everything" removes that.
  Future<void> deleteAccount() async {
    await accounts.deleteAccount();
    _forgetAccount();
  }

  void _forgetAccount() {
    unawaited(sync.forget());
    final user = _user;
    if (user != null) _user = UserProfile(name: user.name);
    _setSocial(null);
    _squadError = null;
    notifyListeners();
    _persist(() => _repo.setCurrentUser(_user), budget: false);
  }

  /// Changes the name shown in the greeting.
  void rename(String name) {
    final user = _user;
    final trimmed = name.trim();
    if (user == null || validateName(trimmed) != null) return;
    _user = UserProfile(name: trimmed, email: user.email);
    notifyListeners();
    _persist(() => _repo.setCurrentUser(_user), budget: false);
  }

  /// Turns the Face ID / passcode lock on or off. Callers verify the owner
  /// with [deviceAuth] first.
  void setAppLock(bool on) {
    if (on == _appLock) return;
    _appLock = on;
    notifyListeners();
    _persist(() => _repo.setAppLock(on), budget: false);
    // Locked: bill reminders stop showing names and amounts.
    _replanReminders(soon: true);
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
    if (reminderScheduler.supported &&
        !_reminders.bills &&
        !_billRemindersOffered) {
      _billRemindersOffered = true;
      offerBillReminders.value = true;
    }
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
  /// The term that ends keeps what's left of its savings goal; the rest
  /// of its money is up to the person to carry into [term].
  void startTerm(Term term, List<UpcomingCost> upcoming) {
    // The demo term ending is no achievement; a real one gets a recap.
    final endsRealTerm = !_needsSetup;
    final saved = endsRealTerm ? _keptSavings : 0.0;
    if (endsRealTerm) {
      _savingsHistory.insert(0, _savedTerm(_term, saved));
    }
    _savingsAsked = true;
    _term = term;
    _bills.clear();
    _expenses.clear();
    _upcoming
      ..clear()
      ..addAll(upcoming);
    _incomes.clear();
    _needsSetup = false;
    _changed();
    _persist(() => _repo.startTerm(term, upcoming, saved: saved));
    if (endsRealTerm) unawaited(checkForRecap());
  }

  /// Offers a recap ([pendingRecap]) for the latest term or month if it
  /// ended after the last one shown. The very first time, it only notes
  /// where history stands, so terms that ended before recaps existed don't
  /// pop up all at once.
  Future<void> checkForRecap() async {
    try {
      final past = await history();
      final seen = await _repo.recapSeenUntil();
      final latest = past.firstOrNull;
      if (seen == null) {
        final until = latest?.endedOn ?? now;
        _persist(() => _repo.setRecapSeenUntil(until));
        return;
      }
      if (latest == null ||
          !latest.endedOn.isAfter(seen) ||
          latest.endedOn == _recapOffered ||
          _disposed) {
        return;
      }
      _recapOffered = latest.endedOn;
      pendingRecap.value = (
        ended: latest,
        before: past
            .skip(1)
            .where((p) => p.term.period == latest.term.period)
            .firstOrNull,
      );
    } on Object catch (error, stack) {
      // A missing recap isn't worth bothering anyone about.
      _report(error, stack, 'while looking for a recap');
    }
  }

  /// Last week's numbers and the words for them, for the card on Home,
  /// until it's dismissed. See [checkForWeekRecap].
  ({WeekRecap week, CoachReply words})? get weekRecap => _weekRecap;
  ({WeekRecap week, CoachReply words})? _weekRecap;

  /// Puts last week's recap on Home, unless it was dismissed: first in the
  /// rules' words, then the coach's once they're written.
  Future<void> checkForWeekRecap() async {
    if (_needsSetup) return;
    final week = lastWeekRecap(
      ledger: ledger,
      expenses: _expenses,
      today: today,
    );
    if (week == null || _weekRecap?.week.start == week.start) return;
    try {
      final seen = await _repo.weekRecapSeen();
      if (_disposed || (seen != null && !seen.isBefore(week.start))) return;
      _weekRecap = (week: week, words: CoachReply.text(week.summary));
      notifyListeners();
      final words = await coach.describeWeek(week);
      if (_disposed || _weekRecap?.week.start != week.start) return;
      _weekRecap = (week: week, words: words);
      notifyListeners();
    } on Object catch (error, stack) {
      _report(error, stack, 'while writing the weekly recap');
    }
  }

  void dismissWeekRecap() {
    final recap = _weekRecap;
    if (recap == null) return;
    _weekRecap = null;
    notifyListeners();
    _persist(() => _repo.setWeekRecapSeen(recap.week.start));
  }

  /// The recap for [past] was shown; it won't be offered again.
  void recapShown(PastTerm past) =>
      _persist(() => _repo.setRecapSeenUntil(past.endedOn));

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
      upcoming: _upcoming,
      jarDeposits: _jarDeposits,
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
    _savingsHistory.insert(0, _savedTerm(_term, next.saved));
    _term = next.term;
    _expenses.clear();
    _upcoming.addAll(added);
    _replace(_incomes, incomes);
    _changed();
    _persist(
      () => _repo.startNewMonth(
        next.term,
        incomes: incomes,
        added: added,
        saved: next.saved,
      ),
    );
    unawaited(checkForRecap());
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
    if (accounts.current != null) {
      try {
        await accounts.signOut();
      } on Object catch (error) {
        debugPrint('Sign-out while erasing failed: $error');
      }
    }
    await sync.forget();
    _apply(await _repo.load());
    _user = null;
    _setSocial(null);
    _squadError = null;
    _changed();
  }

  /// Replaces everything in memory with what was loaded from storage.
  void _apply(BudgetData data) {
    _term = data.term;
    _replace(_expenses, data.expenses);
    _replace(_upcoming, data.upcoming);
    _replace(_bills, data.bills);
    _replace(_incomes, data.incomes);
    _replace(_customCategories, data.customCategories);
    _replace(_friends, data.friends);
    _replace(_splits, data.splits);
    _challengeStart = data.challengeStart;
    _needsSetup = data.needsSetup;
    _appLock = data.appLock;
    _replace(_savingsHistory, data.savingsHistory);
    _savingsAsked = data.savingsAsked;
    _replace(_jars, data.jars);
    _replace(_jarDeposits, data.jarDeposits);
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
    CustomCategory? custom,
  }) => Expense(
    id: 'e${DateTime.now().microsecondsSinceEpoch}',
    amount: amount,
    category: category,
    isNeed: isNeed,
    date: _clock(),
    note: note,
    planned: planned,
    custom: custom,
  );

  void _changed() {
    _recompute();
    notifyListeners();
    _replanReminders();
  }

  // ------------------------------------------------------------ reminders

  final ReminderScheduler reminderScheduler;
  ReminderSettings _reminders;
  ReminderSettings get reminders => _reminders;
  bool _billRemindersOffered = false;
  Timer? _replan;

  /// Turns reminders on or off. Turning one on asks for permission first;
  /// false (and nothing changes) if it isn't given.
  Future<bool> setReminders(ReminderSettings next) async {
    final turningOn =
        (next.bills && !_reminders.bills) ||
        (next.checkIn && !_reminders.checkIn) ||
        (next.weeklyRecap && !_reminders.weeklyRecap);
    if (turningOn && !await reminderScheduler.requestPermission()) {
      return false;
    }
    if (_disposed) return false;
    _reminders = next;
    notifyListeners();
    _persist(() => _repo.setReminders(next), budget: false);
    _replanReminders(soon: true);
    return true;
  }

  /// Plans the next two weeks again, e.g. when the app comes back: a new
  /// day may need tonight's check-in.
  void refreshReminders() => _replanReminders(soon: true);

  /// What a tapped reminder asked for.
  void reminderTapped(ReminderTap tap) => switch (tap) {
    ReminderTap.quickAdd => quickAddRequested.value = true,
    ReminderTap.home => requestedTab.value = 0,
  };

  /// Batches a burst of changes (a sync, a setup) into one replan.
  void _replanReminders({bool soon = false}) {
    if (!reminderScheduler.supported) return;
    _replan?.cancel();
    _replan = Timer(
      soon ? Duration.zero : const Duration(seconds: 2),
      () => unawaited(
        reminderScheduler
            .replaceAll(
              _needsSetup
                  ? const []
                  : planReminders(
                      settings: _reminders,
                      now: _clock(),
                      term: _term,
                      upcoming: _upcoming,
                      expenses: _expenses,
                      hideAmounts: _appLock,
                    ),
            )
            .catchError(
              (Object e, StackTrace s) =>
                  _report(e, s, 'while scheduling reminders'),
            ),
      ),
    );
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
  ///
  /// [budget] is false for what stays on this device (profile, app lock),
  /// so it doesn't trigger a sync upload.
  void _persist(Future<void> Function() write, {bool budget = true}) {
    _pendingWrites++;
    _lastWrite = _lastWrite
        .then((_) => write())
        .then<void>(
          (_) {
            if (budget && !_disposed) sync.localChanged();
          },
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
    _replan?.cancel();
    sync.dispose();
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
      jarDeposits: _jarDeposits,
      today: now,
    );
    _streak = computeStreak(_expenses, now);
  }
}

/// A finished term or month, and the one of the same kind before it (if
/// any) to compare with.
typedef Recap = ({PastTerm ended, PastTerm? before});

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
