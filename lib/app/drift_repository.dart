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
  static const _sessionId = 1;

  Future<void> close() => _db.close();

  // ---------------------------------------------------------------- loading

  @override
  Future<BudgetData> load() async {
    await _seedIfNeeded();
    final term = await _currentTerm();
    _termId = term.id;

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

    return BudgetData(
      term: Term(
        name: term.name,
        start: _day(term.start),
        end: _day(term.end),
        startingBalance: _dollars(term.startingBalanceCents),
        period: term.period,
      ),
      expenses: [for (final r in expenses) _expense(r)],
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
    );
  }

  Future<TermRow> _currentTerm() =>
      (_db.select(_db.terms)
            ..where((t) => t.archivedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(1))
          .getSingle();

  Future<int> _currentTermId() async => _termId ??= (await _currentTerm()).id;

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

  // ----------------------------------------------------------------- writes

  @override
  Future<void> addExpense(Expense expense) async {
    final termId = await _currentTermId();
    await _db.into(_db.expenses).insert(_expenseRow(expense, termId));
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
      ),
    );
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
  Future<void> splitBill(List<BillSplit> splits, Expense myShare) async {
    final termId = await _currentTermId();
    final now = _clock();
    await _db.transaction(() async {
      await _db.batch((b) {
        b.insertAll(_db.billSplits, [
          // Microsecond offsets keep this bill's IOUs in the order given.
          for (var i = 0; i < splits.length; i++)
            _splitRow(splits[i], now.subtract(Duration(microseconds: i))),
        ]);
        b.insert(_db.expenses, _expenseRow(myShare, termId));
      });
    });
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
        _db.expenses,
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

  @override
  Future<void> startTerm(Term term, List<UpcomingCost> upcoming) {
    // Writes that start after this wait for the transaction, then look up
    // the new term instead of using the cached old one.
    _termId = null;
    final now = _clock();
    return _db.transaction(() async {
      final termId = await _replaceCurrentTerm(term, now);
      await (_db.update(_db.repeatingBills)..where((b) => b.endedAt.isNull()))
          .write(RepeatingBillsCompanion(endedAt: Value(now)));
      await _db.batch((b) {
        b.insertAll(_db.upcomingCosts, [
          for (final c in upcoming) _costRow(c, termId),
        ]);
      });
      await _setMeta(_setUpAtKey, now.toIso8601String());
      _termId = termId;
    });
  }

  @override
  Future<void> startNewMonth(
    Term term, {
    required List<Income> incomes,
    required List<UpcomingCost> added,
  }) {
    _termId = null;
    return _db.transaction(() async {
      final oldId = (await _currentTerm()).id;
      final termId = await _replaceCurrentTerm(term, _clock());
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

  /// Archives the current term and inserts [term] as the new current one.
  /// Call inside a transaction.
  Future<int> _replaceCurrentTerm(Term term, DateTime now) async {
    await (_db.update(_db.terms)..where((t) => t.archivedAt.isNull())).write(
      TermsCompanion(archivedAt: Value(now)),
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

  static Expense _expense(ExpenseRow r) => Expense(
    id: r.id,
    amount: _dollars(r.amountCents),
    category: r.category,
    isNeed: r.isNeed,
    date: r.createdAt.toLocal(),
    note: r.note,
    planned: r.isPlanned,
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
