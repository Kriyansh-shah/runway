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
    final splits =
        await (_db.select(_db.billSplits)
              ..where((s) => s.settledAt.isNull())
              ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
            .get();
    final friends = await (_db.select(
      _db.friends,
    )..orderBy([(f) => OrderingTerm.asc(f.position)])).get();
    final challengeStart = await _getMeta(_challengeStartKey);

    return BudgetData(
      term: Term(
        name: term.name,
        start: _day(term.start),
        end: _day(term.end),
        startingBalance: _dollars(term.startingBalanceCents),
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
          ),
      ],
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

  // ----------------------------------------------------------------- writes

  @override
  Future<void> addExpense(Expense expense) async {
    final termId = await _currentTermId();
    await _db.into(_db.expenses).insert(_expenseRow(expense, termId));
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
  Future<void> saveTerm(Term term) async {
    final id = await _currentTermId();
    await (_db.update(_db.terms)..where((t) => t.id.equals(id))).write(
      TermsCompanion(
        name: Value(term.name),
        start: Value(term.start),
        end: Value(term.end),
        startingBalanceCents: Value(_cents(term.startingBalance)),
      ),
    );
  }

  @override
  Future<void> addUpcomingCost(UpcomingCost cost) async {
    final termId = await _currentTermId();
    await _db.into(_db.upcomingCosts).insert(_costRow(cost, termId));
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
      );

  static UpcomingCostsCompanion _costRow(UpcomingCost c, int termId) =>
      UpcomingCostsCompanion.insert(
        id: c.id,
        termId: termId,
        emoji: c.emoji,
        name: c.name,
        amountCents: _cents(c.amount),
        dueDate: c.dueDate,
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
