import 'package:drift/drift.dart';

import 'auth.dart';
import 'database.dart';
import 'format.dart';
import 'models.dart';
import 'repository.dart';

/// Saves everything to `runway.sqlite` on the device.
///
/// On the very first launch the demo data is written once; after that the
/// app only ever shows what's in the database.
class DriftBudgetRepository implements BudgetRepository {
  DriftBudgetRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final RunwayDatabase _db;
  final DateTime Function() _clock;
  int? _termId;

  static const _seededAtKey = 'seeded_at';
  static const _challengeStartKey = 'challenge_start';
  static const _setUpAtKey = 'set_up_at';
  static const _appLockKey = 'app_lock';
  static const _remindersKey = 'reminders';
  static const _recapSeenKey = 'recap_seen_until';
  static const _weekRecapSeenKey = 'week_recap_seen';
  static const _savingsAskedKey = 'savings_asked';
  static const _sessionId = 1;

  Future<void> close() => _db.close();

  // ---------------------------------------------------------------- loading

  @override
  Future<BudgetData> load() async {
    await _seedIfNeeded();
    final term = await _currentTerm();
    _termId = term.id;

    final customs = await _customCategories();
    final expenses =
        await (_db.select(_db.expenses)
              ..where((e) => e.termId.equals(term.id) & e.deletedAt.isNull())
              ..orderBy([(e) => OrderingTerm.asc(e.createdAt)]))
            .get();
    final upcoming =
        await (_db.select(_db.upcomingCosts)
              ..where((c) => c.termId.equals(term.id) & c.paidAt.isNull())
              ..orderBy([(c) => OrderingTerm.asc(c.dueDate)]))
            .get();
    final incomes =
        await (_db.select(_db.incomes)
              ..where((i) => i.termId.equals(term.id) & i.deletedAt.isNull())
              ..orderBy([(i) => OrderingTerm.asc(i.createdAt)]))
            .get();
    final bills = await (_db.select(
      _db.repeatingBills,
    )..where((b) => b.endedAt.isNull())).get();
    final splits =
        await (_db.select(_db.billSplits)
              ..where((s) => s.settledAt.isNull())
              ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
            .get();
    final friends = await (_db.select(
      _db.friends,
    )..orderBy([(f) => OrderingTerm.asc(f.position)])).get();
    final challengeStart = await _getMeta(_challengeStartKey);
    final setUpAt = await _getMeta(_setUpAtKey);
    final appLock = await _getMeta(_appLockKey);
    final reminders = await _getMeta(_remindersKey);
    final savingsAsked = await _getMeta(_savingsAskedKey);
    final past = await _pastTerms();
    final jars = await _openJars();
    final deposits = await (_db.select(
      _db.jarDeposits,
    )..orderBy([(d) => OrderingTerm.asc(d.date)])).get();

    return BudgetData(
      term: _term(term),
      expenses: [for (final r in expenses) _expense(r, customs)],
      upcoming: [
        for (final r in upcoming)
          UpcomingCost(
            id: r.id,
            emoji: r.emoji,
            name: r.name,
            amount: _dollars(r.amountCents),
            dueDate: _day(r.dueDate),
            billId: r.billId,
          ),
      ],
      bills: [
        for (final r in bills)
          RepeatingBill(
            id: r.id,
            emoji: r.emoji,
            name: r.name,
            amount: _dollars(r.amountCents),
            firstDue: _day(r.firstDue),
          ),
      ],
      incomes: [for (final r in incomes) _income(r)],
      customCategories: [...customs.values],
      savingsHistory: [
        for (final t in past)
          SavedTerm(
            name: t.name,
            period: t.period,
            goal: _dollars(t.savingsGoalCents),
            saved: _dollars(t.savedCents ?? 0),
          ),
      ],
      savingsAsked: savingsAsked != null,
      jars: jars,
      jarDeposits: [for (final d in deposits) _deposit(d)],
      friends: [
        for (final r in friends)
          Friend(
            id: r.id,
            name: r.name,
            emoji: r.emoji,
            streak: r.streak,
            noDeliveryDays: [
              for (final c in r.noDeliveryDays.split('')) c == '1',
            ],
          ),
      ],
      splits: [
        for (final r in splits)
          BillSplit(
            id: r.id,
            person: r.person,
            amount: _dollars(r.amountCents),
            note: r.note,
            theyOweYou: r.theyOweYou,
          ),
      ],
      challengeStart: challengeStart == null
          ? dateOnly(_clock())
          : _day(DateTime.parse(challengeStart)),
      needsSetup: setUpAt == null,
      appLock: appLock == 'on',
      reminders: ReminderSettings.decode(reminders),
    );
  }

  /// Finished terms of the user's own, newest first.
  Future<List<TermRow>> _pastTerms() async {
    // The demo term is always the first row: it's seeded into an empty
    // database before any term of the user's own exists.
    final demo =
        await (_db.select(_db.terms)
              ..orderBy([(t) => OrderingTerm.asc(t.id)])
              ..limit(1))
            .getSingleOrNull();
    if (demo == null) return const [];
    return (_db.select(_db.terms)
          ..where((t) => t.archivedAt.isNotNull() & t.id.isNotValue(demo.id))
          ..orderBy([(t) => OrderingTerm.desc(t.id)]))
        .get();
  }

  @override
  Future<List<PastTerm>> history() async {
    final terms = await _pastTerms();
    final ids = [for (final t in terms) t.id];
    final customs = await _customCategories();
    final expenses =
        await (_db.select(_db.expenses)
              ..where((e) => e.termId.isIn(ids) & e.deletedAt.isNull())
              ..orderBy([(e) => OrderingTerm.asc(e.createdAt)]))
            .get();
    final incomes = await (_db.select(
      _db.incomes,
    )..where((i) => i.termId.isIn(ids) & i.deletedAt.isNull())).get();
    return [
      for (final t in terms)
        PastTerm(
          term: _term(t),
          saved: _dollars(t.savedCents ?? 0),
          endedOn: t.archivedAt!.toLocal(),
          expenses: [
            for (final r in expenses)
              if (r.termId == t.id) _expense(r, customs),
          ],
          incomes: [
            for (final r in incomes)
              if (r.termId == t.id) _income(r),
          ],
        ),
    ];
  }

  @override
  Future<DateTime?> recapSeenUntil() async {
    final value = await _getMeta(_recapSeenKey);
    return value == null ? null : DateTime.parse(value);
  }

  @override
  Future<void> setRecapSeenUntil(DateTime endedOn) =>
      _setMeta(_recapSeenKey, endedOn.toUtc().toIso8601String());

  @override
  Future<DateTime?> weekRecapSeen() async {
    final value = await _getMeta(_weekRecapSeenKey);
    return value == null ? null : DateTime.parse(value);
  }

  /// Stored as a local date: weeks are calendar weeks wherever you are.
  @override
  Future<void> setWeekRecapSeen(DateTime weekStart) =>
      _setMeta(_weekRecapSeenKey, dateOnly(weekStart).toIso8601String());

  @override
  Future<void> setSavingsAsked() =>
      _setMeta(_savingsAskedKey, _clock().toIso8601String());

  // ----------------------------------------------------------------- jars

  /// Open jars, oldest first, each with its deposits.
  Future<List<SavingsJar>> _openJars() async {
    final jars =
        await (_db.select(_db.savingsJars)
              ..where((j) => j.endedAt.isNull())
              ..orderBy([(j) => OrderingTerm.asc(j.createdAt)]))
            .get();
    if (jars.isEmpty) return const [];
    final deposits =
        await (_db.select(_db.jarDeposits)
              ..where((d) => d.jarId.isIn([for (final j in jars) j.id]))
              ..orderBy([(d) => OrderingTerm.asc(d.date)]))
            .get();
    return [
      for (final j in jars)
        SavingsJar(
          id: j.id,
          name: j.name,
          target: _dollars(j.targetCents),
          createdAt: j.createdAt,
          deposits: [
            for (final d in deposits)
              if (d.jarId == j.id) _deposit(d),
          ],
        ),
    ];
  }

  static JarDeposit _deposit(JarDepositRow d) => JarDeposit(
    id: d.id,
    jarId: d.jarId,
    amount: _dollars(d.amountCents),
    date: d.date,
  );

  JarDepositsCompanion _depositRow(JarDeposit d) => JarDepositsCompanion.insert(
    id: d.id,
    jarId: d.jarId,
    amountCents: _cents(d.amount),
    date: d.date,
  );

  @override
  Future<void> addJar(SavingsJar jar) async {
    await _db
        .into(_db.savingsJars)
        .insert(
          SavingsJarsCompanion.insert(
            id: jar.id,
            name: jar.name,
            targetCents: _cents(jar.target),
            createdAt: jar.createdAt,
          ),
        );
  }

  @override
  Future<void> addJarDeposit(JarDeposit deposit) =>
      _db.into(_db.jarDeposits).insert(_depositRow(deposit));

  @override
  Future<void> endJar(
    String jarId, {
    required bool bought,
    required JarDeposit takenOut,
    Expense? purchase,
  }) async {
    final termId = await _currentTermId();
    await _db.transaction(() async {
      if (takenOut.amount != 0) {
        await _db.into(_db.jarDeposits).insert(_depositRow(takenOut));
      }
      await (_db.update(
        _db.savingsJars,
      )..where((j) => j.id.equals(jarId))).write(
        SavingsJarsCompanion(
          endedAt: Value(_clock()),
          outcome: Value(bought ? 'bought' : 'dropped'),
        ),
      );
      if (purchase != null) {
        await _db.into(_db.expenses).insert(_expenseRow(purchase, termId));
      }
    });
  }

  Future<TermRow> _currentTerm() =>
      (_db.select(_db.terms)
            ..where((t) => t.archivedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(1))
          .getSingle();

  Future<int> _currentTermId() async => _termId ??= (await _currentTerm()).id;

  /// Every custom category by id, most recently used (or made) first.
  Future<Map<String, CustomCategory>> _customCategories() async {
    final rows = await _db.select(_db.customCategories).get();
    DateTime used(CustomCategoryRow r) => r.lastUsedAt ?? r.createdAt;
    rows.sort((a, b) => used(b).compareTo(used(a)));
    return {
      for (final r in rows)
        r.id: CustomCategory(id: r.id, emoji: r.emoji, name: r.name),
    };
  }

  // ---------------------------------------------------------------- session

  @override
  Future<UserProfile?> currentUser() async {
    final row = await (_db.select(
      _db.sessions,
    )..where((s) => s.id.equals(_sessionId))).getSingleOrNull();
    return row == null ? null : UserProfile(name: row.name, email: row.email);
  }

  @override
  Future<void> setCurrentUser(UserProfile? user) async {
    if (user == null) {
      await _db.delete(_db.sessions).go();
      return;
    }
    await _db
        .into(_db.sessions)
        .insertOnConflictUpdate(
          SessionsCompanion.insert(
            id: const Value(_sessionId),
            name: user.name,
            email: user.email,
            signedInAt: _clock(),
          ),
        );
  }

  @override
  Future<void> setAppLock(bool on) => _setMeta(_appLockKey, on ? 'on' : 'off');

  @override
  Future<void> setReminders(ReminderSettings settings) =>
      _setMeta(_remindersKey, settings.encode());

  // ----------------------------------------------------------------- writes

  @override
  Future<void> addExpense(Expense expense) async {
    final termId = await _currentTermId();
    await _db.transaction(() async {
      await _db.into(_db.expenses).insert(_expenseRow(expense, termId));
      if (expense.custom case final custom?) {
        await (_db.update(_db.customCategories)
              ..where((c) => c.id.equals(custom.id)))
            .write(CustomCategoriesCompanion(lastUsedAt: Value(_clock())));
      }
    });
  }

  @override
  Future<void> updateExpense(Expense expense) async {
    await (_db.update(
      _db.expenses,
    )..where((e) => e.id.equals(expense.id))).write(
      ExpensesCompanion(
        amountCents: Value(_cents(expense.amount)),
        category: Value(expense.category),
        isNeed: Value(expense.isNeed),
        note: Value(expense.note),
        customCategoryId: Value(expense.custom?.id),
      ),
    );
  }

  @override
  Future<void> addCustomCategory(CustomCategory category) async {
    await _db
        .into(_db.customCategories)
        .insert(
          CustomCategoriesCompanion.insert(
            id: category.id,
            emoji: category.emoji,
            name: category.name,
            createdAt: _clock(),
          ),
        );
  }

  @override
  Future<void> updateCustomCategory(CustomCategory category) async {
    await (_db.update(
      _db.customCategories,
    )..where((c) => c.id.equals(category.id))).write(
      CustomCategoriesCompanion(
        emoji: Value(category.emoji),
        name: Value(category.name),
      ),
    );
  }

  @override
  Future<void> deleteCustomCategory(String id) {
    return _db.transaction(() async {
      final category = await (_db.select(
        _db.customCategories,
      )..where((c) => c.id.equals(id))).getSingleOrNull();
      if (category == null) return;
      // Its expenses stay in Other; ones without a note keep its name.
      await (_db.update(_db.expenses)
            ..where((e) => e.customCategoryId.equals(id) & e.note.isNull()))
          .write(ExpensesCompanion(note: Value(category.name)));
      await (_db.update(_db.expenses)
            ..where((e) => e.customCategoryId.equals(id)))
          .write(const ExpensesCompanion(customCategoryId: Value(null)));
      await (_db.delete(
        _db.customCategories,
      )..where((c) => c.id.equals(id))).go();
    });
  }

  @override
  Future<void> deleteExpense(String expenseId) =>
      _setExpenseDeleted(expenseId, _clock());

  @override
  Future<void> restoreExpense(String expenseId) =>
      _setExpenseDeleted(expenseId, null);

  Future<void> _setExpenseDeleted(String id, DateTime? at) async {
    await (_db.update(_db.expenses)..where((e) => e.id.equals(id))).write(
      ExpensesCompanion(deletedAt: Value(at)),
    );
  }

  @override
  Future<void> splitBill(List<BillSplit> splits, Expense? myShare) async {
    final termId = await _currentTermId();
    final now = _clock();
    await _db.transaction(() async {
      await _db.batch((b) {
        b.insertAll(_db.billSplits, [
          // Microsecond offsets keep this bill's IOUs in the order given.
          for (var i = 0; i < splits.length; i++)
            _splitRow(splits[i], now.subtract(Duration(microseconds: i))),
        ]);
        if (myShare != null) {
          b.insert(_db.expenses, _expenseRow(myShare, termId));
        }
      });
    });
  }

  @override
  Future<Set<String>> sharedExpenseIds() async {
    final rows =
        await (_db.selectOnly(_db.expenses)
              ..addColumns([_db.expenses.id])
              ..where(_db.expenses.id.like('sx-%')))
            .get();
    return {for (final r in rows) r.read(_db.expenses.id)!};
  }

  @override
  Future<void> settleSplit(String splitId) async {
    await (_db.update(_db.billSplits)..where((s) => s.id.equals(splitId)))
        .write(BillSplitsCompanion(settledAt: Value(_clock())));
  }

  @override
  Future<void> saveTerm(
    Term term, {
    List<UpcomingCost> added = const [],
  }) async {
    final id = await _currentTermId();
    await _db.transaction(() async {
      await (_db.update(_db.terms)..where((t) => t.id.equals(id))).write(
        TermsCompanion(
          name: Value(term.name),
          start: Value(term.start),
          end: Value(term.end),
          startingBalanceCents: Value(_cents(term.startingBalance)),
          period: Value(term.period),
          savingsGoalCents: Value(_cents(term.savingsGoal)),
        ),
      );
      await _db.batch((b) {
        b.insertAll(_db.upcomingCosts, [
          for (final c in added) _costRow(c, id),
        ]);
      });
    });
  }

  @override
  Future<void> addUpcomingCost(UpcomingCost cost) async {
    final termId = await _currentTermId();
    await _db.into(_db.upcomingCosts).insert(_costRow(cost, termId));
  }

  @override
  Future<void> updateUpcomingCost(UpcomingCost cost) async {
    await (_db.update(
      _db.upcomingCosts,
    )..where((c) => c.id.equals(cost.id))).write(
      UpcomingCostsCompanion(
        name: Value(cost.name),
        amountCents: Value(_cents(cost.amount)),
        dueDate: Value(cost.dueDate),
      ),
    );
  }

  @override
  Future<void> updateBill(RepeatingBill bill, {required DateTime from}) {
    return _db.transaction(() async {
      await (_db.update(
        _db.repeatingBills,
      )..where((b) => b.id.equals(bill.id))).write(
        RepeatingBillsCompanion(
          name: Value(bill.name),
          amountCents: Value(_cents(bill.amount)),
        ),
      );
      await (_db.update(_db.upcomingCosts)..where(
            (c) =>
                c.billId.equals(bill.id) &
                c.paidAt.isNull() &
                c.dueDate.isBiggerOrEqualValue(from),
          ))
          .write(
            UpcomingCostsCompanion(
              name: Value(bill.name),
              amountCents: Value(_cents(bill.amount)),
            ),
          );
    });
  }

  @override
  Future<void> updateIncome(Income income, {Income? continuedBy}) async {
    final termId = await _currentTermId();
    await _db.transaction(() async {
      await (_db.update(
        _db.incomes,
      )..where((i) => i.id.equals(income.id))).write(
        IncomesCompanion(
          name: Value(income.name),
          amountCents: Value(_cents(income.amount)),
          firstDate: Value(income.firstDate),
          endsOn: Value(income.endsOn),
        ),
      );
      if (continuedBy != null) {
        await _db
            .into(_db.incomes)
            .insert(_incomeRow(continuedBy, termId, _clock()));
      }
    });
  }

  @override
  Future<void> addBill(RepeatingBill bill, List<UpcomingCost> due) async {
    final termId = await _currentTermId();
    await _db.transaction(() async {
      await _db
          .into(_db.repeatingBills)
          .insert(
            RepeatingBillsCompanion.insert(
              id: bill.id,
              emoji: bill.emoji,
              name: bill.name,
              amountCents: _cents(bill.amount),
              firstDue: bill.firstDue,
              createdAt: _clock(),
            ),
          );
      await _db.batch((b) {
        b.insertAll(_db.upcomingCosts, [
          for (final c in due) _costRow(c, termId),
        ]);
      });
    });
  }

  @override
  Future<void> stopBill(String billId, {required DateTime from}) {
    return _db.transaction(() async {
      await (_db.update(_db.repeatingBills)..where((b) => b.id.equals(billId)))
          .write(RepeatingBillsCompanion(endedAt: Value(_clock())));
      await (_db.delete(_db.upcomingCosts)..where(
            (c) =>
                c.billId.equals(billId) &
                c.paidAt.isNull() &
                c.dueDate.isBiggerOrEqualValue(from),
          ))
          .go();
    });
  }

  @override
  Future<void> deleteUpcomingCost(String costId) async {
    await (_db.delete(
      _db.upcomingCosts,
    )..where((c) => c.id.equals(costId))).go();
  }

  @override
  Future<void> payUpcomingCost(String costId, Expense expense) async {
    final termId = await _currentTermId();
    await _db.transaction(() async {
      await (_db.update(_db.upcomingCosts)..where((c) => c.id.equals(costId)))
          .write(UpcomingCostsCompanion(paidAt: Value(_clock())));
      await _db.into(_db.expenses).insert(_expenseRow(expense, termId));
    });
  }

  @override
  Future<void> addIncome(Income income) async {
    final termId = await _currentTermId();
    await _db.into(_db.incomes).insert(_incomeRow(income, termId, _clock()));
  }

  @override
  Future<void> stopIncome(String incomeId, DateTime endsOn) async {
    await (_db.update(_db.incomes)..where((i) => i.id.equals(incomeId))).write(
      IncomesCompanion(endsOn: Value(endsOn)),
    );
  }

  @override
  Future<void> deleteIncome(String incomeId) async {
    await (_db.update(_db.incomes)..where((i) => i.id.equals(incomeId))).write(
      IncomesCompanion(deletedAt: Value(_clock())),
    );
  }

  @override
  Future<void> eraseEverything() async {
    _termId = null;
    await _db.transaction(() async {
      // Children before the terms they reference (foreign keys are on).
      for (final table in <TableInfo<Table, Object?>>[
        _db.jarDeposits,
        _db.savingsJars,
        _db.expenses,
        _db.customCategories,
        _db.upcomingCosts,
        _db.repeatingBills,
        _db.incomes,
        _db.billSplits,
        _db.friends,
        _db.sessions,
        _db.meta,
        _db.terms,
      ]) {
        await _db.delete(table).go();
      }
    });
    // Deleted rows can linger in free pages of the file; rewrite it so the
    // old data is really gone from disk.
    await _db.customStatement('VACUUM');
  }

  /// Meta keys that stay on this device instead of syncing.
  static const _deviceOnlyMeta = {_appLockKey, _remindersKey};

  /// Synced tables, parents before the children that reference them.
  List<TableInfo<Table, Object?>> get _syncedTables => [
    _db.terms,
    _db.customCategories,
    _db.repeatingBills,
    _db.incomes,
    _db.expenses,
    _db.upcomingCosts,
    _db.billSplits,
    _db.friends,
    _db.savingsJars,
    _db.jarDeposits,
    _db.meta,
  ];

  @override
  Future<Map<String, Object?>> exportSnapshot() async {
    final tables = <String, Object?>{};
    for (final table in _syncedTables) {
      final rows = await _db.select(table).get();
      tables[table.actualTableName] = [
        for (final row in rows)
          if (row is MetaRow && _deviceOnlyMeta.contains(row.key))
            null
          else
            (row as DataClass).toJson(),
      ].nonNulls.toList();
    }
    return {'schema': _db.schemaVersion, 'tables': tables};
  }

  @override
  Future<void> importSnapshot(Map<String, Object?> snapshot) async {
    final schema = snapshot['schema'] as int? ?? 0;
    // Sync started at schema 6. A 6 snapshot reads fine as a 7 one: 7 only
    // added the jar tables, which it simply doesn't have.
    if (schema > _db.schemaVersion) throw const SnapshotTooNewException();
    final tables = (snapshot['tables'] as Map).cast<String, Object?>();
    List<Map<String, dynamic>> rows(TableInfo<Table, Object?> t) => [
      for (final r in (tables[t.actualTableName] as List?) ?? const [])
        (r as Map).cast<String, dynamic>(),
    ];
    final keptMeta = await (_db.select(
      _db.meta,
    )..where((m) => m.key.isIn(_deviceOnlyMeta))).get();
    _termId = null;
    await _db.transaction(() async {
      for (final table in _syncedTables.reversed) {
        await _db.delete(table).go();
      }
      await _db.batch((b) {
        b.insertAll(_db.terms, rows(_db.terms).map(TermRow.fromJson));
        b.insertAll(
          _db.customCategories,
          rows(_db.customCategories).map(CustomCategoryRow.fromJson),
        );
        b.insertAll(
          _db.repeatingBills,
          rows(_db.repeatingBills).map(RepeatingBillRow.fromJson),
        );
        b.insertAll(_db.incomes, rows(_db.incomes).map(IncomeRow.fromJson));
        b.insertAll(_db.expenses, rows(_db.expenses).map(ExpenseRow.fromJson));
        b.insertAll(
          _db.upcomingCosts,
          rows(_db.upcomingCosts).map(UpcomingCostRow.fromJson),
        );
        b.insertAll(
          _db.billSplits,
          rows(_db.billSplits).map(BillSplitRow.fromJson),
        );
        b.insertAll(_db.friends, rows(_db.friends).map(FriendRow.fromJson));
        b.insertAll(
          _db.savingsJars,
          rows(_db.savingsJars).map(SavingsJarRow.fromJson),
        );
        b.insertAll(
          _db.jarDeposits,
          rows(_db.jarDeposits).map(JarDepositRow.fromJson),
        );
        b.insertAll(_db.meta, [
          ...rows(_db.meta)
              .map(MetaRow.fromJson)
              .where((m) => !_deviceOnlyMeta.contains(m.key)),
          ...keptMeta,
        ]);
      });
    });
  }

  @override
  Future<void> startTerm(
    Term term,
    List<UpcomingCost> upcoming, {
    double saved = 0,
  }) {
    // Writes that start after this wait for the transaction, then look up
    // the new term instead of using the cached old one.
    _termId = null;
    final now = _clock();
    return _db.transaction(() async {
      final termId = await _replaceCurrentTerm(term, now, saved);
      await (_db.update(_db.repeatingBills)..where((b) => b.endedAt.isNull()))
          .write(RepeatingBillsCompanion(endedAt: Value(now)));
      await _db.batch((b) {
        b.insertAll(_db.upcomingCosts, [
          for (final c in upcoming) _costRow(c, termId),
        ]);
      });
      await _setMeta(_setUpAtKey, now.toIso8601String());
      await _setMeta(_savingsAskedKey, now.toIso8601String());
      _termId = termId;
    });
  }

  @override
  Future<void> startNewMonth(
    Term term, {
    required List<Income> incomes,
    required List<UpcomingCost> added,
    double saved = 0,
  }) {
    _termId = null;
    return _db.transaction(() async {
      final oldId = (await _currentTerm()).id;
      final termId = await _replaceCurrentTerm(term, _clock(), saved);
      // Still owed, so still reserved: the costs move with the money.
      await (_db.update(_db.upcomingCosts)
            ..where((c) => c.termId.equals(oldId) & c.paidAt.isNull()))
          .write(UpcomingCostsCompanion(termId: Value(termId)));
      await _db.batch((b) {
        b.insertAll(_db.upcomingCosts, [
          for (final c in added) _costRow(c, termId),
        ]);
        b.insertAll(_db.incomes, [
          for (final i in incomes) _incomeRow(i, termId, _clock()),
        ]);
      });
      _termId = termId;
    });
  }

  /// Archives the current term, with [saved] kept of its savings goal,
  /// and inserts [term] as the new current one. Call inside a transaction.
  Future<int> _replaceCurrentTerm(Term term, DateTime now, double saved) async {
    await (_db.update(_db.terms)..where((t) => t.archivedAt.isNull())).write(
      TermsCompanion(archivedAt: Value(now), savedCents: Value(_cents(saved))),
    );
    return _db
        .into(_db.terms)
        .insert(
          TermsCompanion.insert(
            name: term.name,
            start: term.start,
            end: term.end,
            startingBalanceCents: _cents(term.startingBalance),
            period: Value(term.period),
            savingsGoalCents: Value(_cents(term.savingsGoal)),
          ),
        );
  }

  // ---------------------------------------------------------------- seeding

  Future<void> _seedIfNeeded() async {
    if (await _getMeta(_seededAtKey) != null) return;
    final now = _clock();
    final data = MockBudgetRepository.seed(now);
    await _db.transaction(() async {
      final termId = await _db
          .into(_db.terms)
          .insert(
            TermsCompanion.insert(
              name: data.term.name,
              start: data.term.start,
              end: data.term.end,
              startingBalanceCents: _cents(data.term.startingBalance),
            ),
          );
      await _db.batch((b) {
        b.insertAll(_db.expenses, [
          for (final e in data.expenses) _expenseRow(e, termId),
        ]);
        b.insertAll(_db.upcomingCosts, [
          for (final c in data.upcoming) _costRow(c, termId),
        ]);
        b.insertAll(_db.friends, [
          for (var i = 0; i < data.friends.length; i++)
            FriendsCompanion.insert(
              id: data.friends[i].id,
              position: i,
              name: data.friends[i].name,
              emoji: data.friends[i].emoji,
              streak: data.friends[i].streak,
              noDeliveryDays: data.friends[i].noDeliveryDays
                  .map((ok) => ok ? '1' : '0')
                  .join(),
            ),
        ]);
        b.insertAll(_db.billSplits, [
          for (var i = 0; i < data.splits.length; i++)
            _splitRow(data.splits[i], now.subtract(Duration(minutes: i + 1))),
        ]);
      });
      await _setMeta(_challengeStartKey, data.challengeStart.toIso8601String());
      await _setMeta(_seededAtKey, now.toIso8601String());
    });
  }

  Future<String?> _getMeta(String key) async {
    final row = await (_db.select(
      _db.meta,
    )..where((m) => m.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _setMeta(String key, String value) => _db
      .into(_db.meta)
      .insertOnConflictUpdate(MetaCompanion.insert(key: key, value: value));

  // ---------------------------------------------------------------- mapping

  static int _cents(double dollars) => (dollars * 100).round();
  static double _dollars(int cents) => cents / 100;

  /// Calendar dates (term start, due dates) come back as local midnight.
  static DateTime _day(DateTime d) => dateOnly(d.toLocal());

  static Term _term(TermRow r) => Term(
    name: r.name,
    start: _day(r.start),
    end: _day(r.end),
    startingBalance: _dollars(r.startingBalanceCents),
    period: r.period,
    savingsGoal: _dollars(r.savingsGoalCents),
  );

  static Expense _expense(ExpenseRow r, Map<String, CustomCategory> customs) =>
      Expense(
        id: r.id,
        amount: _dollars(r.amountCents),
        category: r.category,
        isNeed: r.isNeed,
        date: r.createdAt.toLocal(),
        note: r.note,
        planned: r.isPlanned,
        custom: customs[r.customCategoryId],
      );

  static Income _income(IncomeRow r) => Income(
    id: r.id,
    name: r.name,
    amount: _dollars(r.amountCents),
    frequency: r.frequency,
    firstDate: _day(r.firstDate),
    endsOn: r.endsOn == null ? null : _day(r.endsOn!),
  );

  static ExpensesCompanion _expenseRow(Expense e, int termId) =>
      ExpensesCompanion.insert(
        id: e.id,
        termId: termId,
        amountCents: _cents(e.amount),
        category: e.category,
        isNeed: e.isNeed,
        note: Value(e.note),
        createdAt: e.date,
        isPlanned: Value(e.planned),
        customCategoryId: Value(e.custom?.id),
      );

  static UpcomingCostsCompanion _costRow(UpcomingCost c, int termId) =>
      UpcomingCostsCompanion.insert(
        id: c.id,
        termId: termId,
        emoji: c.emoji,
        name: c.name,
        amountCents: _cents(c.amount),
        dueDate: c.dueDate,
        billId: Value(c.billId),
      );

  static IncomesCompanion _incomeRow(
    Income i,
    int termId,
    DateTime createdAt,
  ) => IncomesCompanion.insert(
    id: i.id,
    termId: termId,
    name: i.name,
    amountCents: _cents(i.amount),
    frequency: i.frequency,
    firstDate: i.firstDate,
    endsOn: Value(i.endsOn),
    createdAt: createdAt,
  );

  static BillSplitsCompanion _splitRow(BillSplit s, DateTime createdAt) =>
      BillSplitsCompanion.insert(
        id: s.id,
        person: s.person,
        amountCents: _cents(s.amount),
        note: s.note,
        theyOweYou: s.theyOweYou,
        createdAt: createdAt,
      );
}
