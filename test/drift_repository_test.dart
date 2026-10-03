import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/app_state.dart';
import 'package:runway/app/auth.dart';
import 'package:runway/app/budget_math.dart';
import 'package:runway/app/database.dart';
import 'package:runway/app/drift_repository.dart';
import 'package:runway/app/models.dart';
import 'package:runway/app/repository.dart';

/// Every test uses a real SQLite file, and "reopening" means closing the
/// database and opening the same file again — exactly like quitting and
/// relaunching the app.
void main() {
  final now = DateTime(2026, 10, 2, 15);
  late Directory dir;
  late File file;
  final open = <DriftBudgetRepository>[];

  DriftBudgetRepository openRepo({DateTime? at}) {
    final repo = DriftBudgetRepository(
      RunwayDatabase(NativeDatabase(file)),
      clock: () => at ?? now,
    );
    open.add(repo);
    return repo;
  }

  /// Closes [repo] and opens the same file again ("relaunch the app").
  Future<DriftBudgetRepository> reopen(DriftBudgetRepository repo) async {
    await repo.close();
    open.remove(repo);
    return openRepo();
  }

  Expense expense(String id, double amount, {String? note}) => Expense(
    id: id,
    amount: amount,
    category: ExpenseCategory.rideshare,
    isNeed: true,
    date: now.add(const Duration(minutes: 5)),
    note: note,
  );

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('runway_db_test');
    file = File('${dir.path}/runway.sqlite');
  });

  tearDown(() async {
    for (final r in open) {
      await r.close();
    }
    open.clear();
    dir.deleteSync(recursive: true);
  });

  test('first launch seeds the demo data exactly once', () async {
    var repo = openRepo();
    final first = await repo.load();
    final mock = MockBudgetRepository.seed(now);
    expect(first.expenses.length, mock.expenses.length);
    expect(first.upcoming.length, 3);
    expect(first.friends.map((f) => f.name), ['Maya', 'Aarav', 'Jules']);
    expect(first.splits.map((s) => s.person), ['Aarav', 'Maya']);

    // Same numbers as the in-memory demo: 14 days short.
    final s = computeRunway(
      term: first.term,
      expenses: first.expenses,
      upcoming: first.upcoming,
      today: now,
    );
    expect(s.daysShort, 14);
    expect(s.totalSpent, closeTo(MockBudgetRepository.seededTotal + 4.5, 1e-9));

    repo = await reopen(repo);
    final second = await repo.load();
    expect(second.expenses.length, first.expenses.length); // not re-seeded
  });

  test('expenses survive closing and reopening', () async {
    var repo = openRepo();
    await repo.load();
    await repo.addExpense(expense('e1', 27.35, note: 'Uber to airport'));

    repo = await reopen(repo);
    final data = await repo.load();
    final e = data.expenses.singleWhere((e) => e.id == 'e1');
    expect(e.amount, 27.35);
    expect(e.note, 'Uber to airport');
    expect(e.category, ExpenseCategory.rideshare);
    expect(e.isNeed, isTrue);
    expect(e.date, now.add(const Duration(minutes: 5)));
  });

  test('money is stored as exact cents', () async {
    var repo = openRepo();
    await repo.load();
    // 0.1 + 0.2 style values must not drift.
    for (final (i, amount) in [0.1, 0.2, 12.40, 4.5, 1299.99].indexed) {
      await repo.addExpense(expense('c$i', amount));
    }
    repo = await reopen(repo);
    final amounts = (await repo.load()).expenses
        .where((e) => e.id.startsWith('c'))
        .map((e) => e.amount);
    expect(amounts, [0.1, 0.2, 12.40, 4.5, 1299.99]);
  });

  test('calendar dates come back as local midnight', () async {
    var repo = openRepo();
    final before = await repo.load();
    repo = await reopen(repo);
    final after = await repo.load();
    expect(after.term.start, before.term.start);
    expect(after.term.end, DateTime(2026, 12, 11));
    expect(after.upcoming.first.dueDate, DateTime(2026, 10, 11));
    expect(after.challengeStart, DateTime(2026, 9, 29));
  });

  test('a split bill saves IOUs and your share together, in order', () async {
    var repo = openRepo();
    await repo.load();
    final splits = [
      for (final p in ['Maya', 'Jules'])
        BillSplit(
          id: 's-$p',
          person: p,
          amount: 12,
          note: 'Takeout',
          theyOweYou: true,
        ),
    ];
    await repo.splitBill(splits, expense('mine', 12, note: 'Takeout'));

    repo = await reopen(repo);
    final data = await repo.load();
    expect(data.splits.map((s) => s.person), [
      'Maya',
      'Jules',
      'Aarav',
      'Maya',
    ]);
    expect(data.expenses.where((e) => e.id == 'mine'), hasLength(1));
  });

  test('a failed split bill saves nothing', () async {
    var repo = openRepo();
    final before = await repo.load();
    final clash = BillSplit(
      id: 'dup',
      person: 'Maya',
      amount: 5,
      note: 'x',
      theyOweYou: true,
    );
    // The duplicate id makes the second insert fail mid-transaction.
    await expectLater(
      repo.splitBill([clash, clash], expense('never', 5)),
      throwsA(anything),
    );

    repo = await reopen(repo);
    final after = await repo.load();
    expect(after.splits.length, before.splits.length);
    expect(after.expenses.any((e) => e.id == 'never'), isFalse);
  });

  test('settled splits stay hidden after reopening', () async {
    var repo = openRepo();
    await repo.load();
    await repo.settleSplit('pizza');
    repo = await reopen(repo);
    expect((await repo.load()).splits.map((s) => s.id), ['wifi']);
  });

  test('the signed-in user is remembered until sign out', () async {
    var repo = openRepo();
    await repo.load();
    expect(await repo.currentUser(), isNull);

    await repo.setCurrentUser(
      const UserProfile(name: 'Maya', email: 'maya@uni.edu'),
    );
    repo = await reopen(repo);
    final user = await repo.currentUser();
    expect(user?.name, 'Maya');
    expect(user?.email, 'maya@uni.edu');

    await repo.setCurrentUser(null);
    repo = await reopen(repo);
    expect(await repo.currentUser(), isNull);
  });

  test('term changes and new upcoming costs are saved', () async {
    var repo = openRepo();
    final data = await repo.load();
    await repo.saveTerm(
      Term(
        name: 'Spring term',
        start: data.term.start,
        end: DateTime(2027, 5, 1),
        startingBalance: 4100.50,
      ),
    );
    await repo.addUpcomingCost(
      UpcomingCost(
        id: 'concert',
        emoji: '🎤',
        name: 'Concert',
        amount: 60,
        dueDate: DateTime(2026, 11, 2),
      ),
    );

    repo = await reopen(repo);
    final after = await repo.load();
    expect(after.term.name, 'Spring term');
    expect(after.term.end, DateTime(2027, 5, 1));
    expect(after.term.startingBalance, 4100.50);
    expect(after.upcoming.map((c) => c.name), contains('Concert'));
  });

  test('AppState changes reach the database', () async {
    var repo = openRepo();
    final state = AppState(
      repository: repo,
      data: await repo.load(),
      clock: () => now,
    );
    state.addExpense(
      amount: 9.99,
      category: ExpenseCategory.fun,
      isNeed: false,
      note: 'Movie',
    );
    state.splitBill(
      description: 'Groceries',
      total: 30,
      roommates: state.friends.take(2).toList(),
      category: ExpenseCategory.groceries,
      isNeed: true,
    );
    state.settleSplit('wifi');
    state.signedIn(const UserProfile(name: 'Alex', email: 'alex@uni.edu'));
    await pumpEventQueue(times: 100); // let the background saves finish

    repo = await reopen(repo);
    final data = await repo.load();
    final relaunched = AppState(
      repository: repo,
      data: data,
      user: await repo.currentUser(),
      clock: () => now,
    );
    expect(relaunched.user?.name, 'Alex');
    expect(
      relaunched.recentExpenses(10).map((e) => e.title),
      containsAll(['Movie', 'Groceries']),
    );
    expect(relaunched.splits.map((s) => s.note), [
      'Groceries',
      'Groceries',
      'Pizza night',
    ]);
    expect(
      relaunched.snapshot.totalSpent,
      closeTo(state.snapshot.totalSpent, 1e-9),
    );
  });
}
