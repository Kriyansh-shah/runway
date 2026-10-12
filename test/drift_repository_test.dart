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

  test('setup replaces the demo term and survives reopening', () async {
    var repo = openRepo();
    final demo = await repo.load();
    expect(demo.needsSetup, isTrue);

    final state = AppState(repository: repo, data: demo, clock: () => now);
    final term = Term(
      name: 'Spring term',
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 12, 20),
      startingBalance: 2500,
    );
    state.startTerm(term, [
      UpcomingCost(
        id: 'u1',
        emoji: '📌',
        name: 'Flight home',
        amount: 300,
        dueDate: DateTime(2026, 12, 18),
      ),
    ]);
    expect(state.needsSetup, isFalse);
    expect(state.recentExpenses(), isEmpty);
    expect(state.snapshot.available, 2200);
    // Logged right after setup, so it must land in the new term.
    state.addExpense(
      amount: 12,
      category: ExpenseCategory.coffee,
      isNeed: false,
    );
    await pumpEventQueue(times: 100);

    repo = await reopen(repo);
    final data = await repo.load();
    expect(data.needsSetup, isFalse);
    expect(data.term.name, 'Spring term');
    expect(data.term.start, DateTime(2026, 10, 1));
    expect(data.term.end, DateTime(2026, 12, 20));
    expect(data.term.startingBalance, 2500);
    expect(data.expenses.map((e) => e.amount), [12]);
    expect(data.upcoming.map((c) => c.name), ['Flight home']);
    // Squad stays until it has a real backend.
    expect(data.friends.length, demo.friends.length);
  });

  test('money coming in survives reopening, stopping and deleting', () async {
    var repo = openRepo();
    await repo.load();
    await repo.addIncome(
      Income(
        id: 'job',
        name: 'Campus job',
        amount: 312.40,
        frequency: IncomeFrequency.biweekly,
        firstDate: DateTime(2026, 10, 9),
      ),
    );
    await repo.addIncome(
      Income(
        id: 'gift',
        name: 'Birthday',
        amount: 50,
        frequency: IncomeFrequency.once,
        firstDate: DateTime(2026, 10, 1),
      ),
    );
    await repo.stopIncome('job', DateTime(2026, 11, 20));
    await repo.deleteIncome('gift');

    repo = await reopen(repo);
    final job = (await repo.load()).incomes.single;
    expect(job.name, 'Campus job');
    expect(job.amount, 312.40);
    expect(job.frequency, IncomeFrequency.biweekly);
    expect(job.firstDate, DateTime(2026, 10, 9));
    expect(job.endsOn, DateTime(2026, 11, 20));
  });

  test('paying a cost logs a planned expense and removes it', () async {
    var repo = openRepo();
    final before = await repo.load();
    final phone = before.upcoming.first;
    await repo.payUpcomingCost(
      phone.id,
      Expense(
        id: 'paid-phone',
        amount: phone.amount,
        category: ExpenseCategory.bills,
        isNeed: true,
        date: now,
        note: phone.name,
        planned: true,
      ),
    );
    await repo.deleteUpcomingCost(before.upcoming.last.id);

    repo = await reopen(repo);
    final after = await repo.load();
    expect(after.upcoming.map((c) => c.id), [before.upcoming[1].id]);
    final paid = after.expenses.singleWhere((e) => e.id == 'paid-phone');
    expect(paid.planned, isTrue);
    expect(paid.amount, phone.amount);
    expect(after.expenses.where((e) => e.planned), hasLength(1));
  });

  test('a failed payment leaves the cost unpaid', () async {
    final repo = openRepo();
    final before = await repo.load();
    // Reusing an existing expense id makes the insert fail mid-transaction.
    final clash = before.expenses.first;
    await expectLater(
      repo.payUpcomingCost(
        before.upcoming.first.id,
        Expense(
          id: clash.id,
          amount: 1,
          category: ExpenseCategory.bills,
          isNeed: true,
          date: now,
          planned: true,
        ),
      ),
      throwsA(anything),
    );
    expect((await repo.load()).upcoming.length, before.upcoming.length);
  });

  test('erasing everything starts over like a fresh install', () async {
    var repo = openRepo();
    final state = AppState(
      repository: repo,
      data: await repo.load(),
      user: const UserProfile(name: 'Alex', email: 'alex@uni.edu'),
      clock: () => now,
    );
    state.startTerm(
      Term(
        name: 'Mine',
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 12, 1),
        startingBalance: 900,
      ),
      const [],
    );
    state.addIncome(
      name: 'Job',
      amount: 100,
      frequency: IncomeFrequency.weekly,
      firstDate: now,
    );
    await pumpEventQueue(times: 100);

    await state.eraseEverything();
    expect(state.user, isNull);
    expect(state.needsSetup, isTrue);
    expect(state.incomes, isEmpty);

    repo = await reopen(repo);
    expect(await repo.currentUser(), isNull);
    final data = await repo.load();
    expect(data.needsSetup, isTrue);
    expect(data.term.name, 'Fall term'); // demo again, until set up
    expect(data.incomes, isEmpty);
  });

  test('a version 1 database upgrades without losing data', () async {
    var repo = openRepo();
    await repo.load();
    await repo.addExpense(expense('old', 7.25, note: 'From v1'));
    await repo.close();
    open.remove(repo);

    // Turn the file back into the version 1 schema.
    final db = RunwayDatabase(NativeDatabase(file));
    await db.customStatement('DROP TABLE incomes');
    await db.customStatement('ALTER TABLE expenses DROP COLUMN is_planned');
    await db.customStatement('ALTER TABLE upcoming_costs DROP COLUMN bill_id');
    await db.customStatement('DROP TABLE repeating_bills');
    await db.customStatement('ALTER TABLE terms DROP COLUMN period');
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();

    repo = openRepo();
    final data = await repo.load();
    final old = data.expenses.singleWhere((e) => e.id == 'old');
    expect(old.note, 'From v1');
    expect(old.planned, isFalse);
    await repo.addIncome(
      Income(
        id: 'new',
        name: 'Stipend',
        amount: 80,
        frequency: IncomeFrequency.monthly,
        firstDate: DateTime(2026, 10, 15),
      ),
    );
    expect((await repo.load()).incomes.single.name, 'Stipend');
  });

  test('a version 2 database upgrades with every term a semester', () async {
    var repo = openRepo();
    await repo.load();
    await repo.close();
    open.remove(repo);

    final db = RunwayDatabase(NativeDatabase(file));
    await db.customStatement('ALTER TABLE upcoming_costs DROP COLUMN bill_id');
    await db.customStatement('DROP TABLE repeating_bills');
    await db.customStatement('ALTER TABLE terms DROP COLUMN period');
    await db.customStatement('PRAGMA user_version = 2');
    await db.close();

    repo = openRepo();
    final term = (await repo.load()).term;
    expect(term.name, 'Fall term');
    expect(term.period, BudgetPeriod.semester);
  });

  test('a monthly budget starts the next month by itself', () async {
    var repo = openRepo();
    var clock = now;
    final state = AppState(
      repository: repo,
      data: await repo.load(),
      clock: () => clock,
    );
    state.startTerm(
      Term(
        name: 'October',
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 31),
        startingBalance: 500,
        period: BudgetPeriod.monthly,
      ),
      [
        UpcomingCost(
          id: 'rent',
          emoji: '🏠',
          name: 'Rent',
          amount: 400,
          dueDate: DateTime(2026, 10, 28),
        ),
      ],
    );
    state.addIncome(
      name: 'Job',
      amount: 100,
      frequency: IncomeFrequency.weekly,
      firstDate: DateTime(2026, 10, 2), // 5 paydays in October
    );
    state.addIncome(
      name: 'Gift',
      amount: 20,
      frequency: IncomeFrequency.once,
      firstDate: DateTime(2026, 10, 2),
    );
    state.addExpense(
      amount: 1120,
      category: ExpenseCategory.groceries,
      isNeed: true,
    );
    state.startNewMonthIfDue(); // still October: nothing happens
    expect(state.term.name, 'October');

    clock = DateTime(2026, 11, 2, 9);
    state.startNewMonthIfDue();
    expect(state.term.name, 'November');
    expect(state.term.start, DateTime(2026, 11, 1));
    expect(state.term.end, DateTime(2026, 11, 30));
    expect(state.term.startingBalance, 0); // 500 + 520 − 1120 = −100
    expect(state.recentExpenses(), isEmpty);
    expect(state.comingUp.map((c) => (c.name, c.amount)), [
      ('Rent', 400.0),
      ('Overspent in October', 100.0),
    ]);
    expect(state.incomes.map((i) => i.name), ['Job']);
    // October's paydays stay with October; November's first is on the 6th.
    expect(state.snapshot.received, 0);
    expect(state.nextIncome?.date, DateTime(2026, 11, 6));
    await pumpEventQueue(times: 100);

    repo = await reopen(repo);
    final data = await repo.load();
    expect(data.term.name, 'November');
    expect(data.term.period, BudgetPeriod.monthly);
    expect(data.term.startingBalance, 0);
    expect(data.expenses, isEmpty);
    expect(data.upcoming.map((c) => c.name), ['Rent', 'Overspent in October']);
    expect(data.incomes.single.frequency, IncomeFrequency.weekly);
  });

  group('repeating bills', () {
    late DriftBudgetRepository repo;
    late AppState state;
    var clock = now;
    final rent = UpcomingCost(
      id: 'rent',
      emoji: '🏠',
      name: 'Rent',
      amount: 800,
      dueDate: DateTime(2026, 10, 5),
    );

    Future<void> start(Term term) async {
      clock = now;
      repo = openRepo();
      state = AppState(
        repository: repo,
        data: await repo.load(),
        clock: () => clock,
      );
      state.startTerm(term, const []);
      state.addUpcomingCost(rent, monthly: true);
    }

    Future<BudgetData> reload() async {
      await pumpEventQueue(times: 100);
      repo = await reopen(repo);
      return repo.load();
    }

    final semester = Term(
      name: 'Fall term',
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 12, 20),
      startingBalance: 5000,
    );

    test('a semester reserves every month of it up front', () async {
      await start(semester);
      expect(state.comingUp.map((c) => c.dueDate), [
        DateTime(2026, 10, 5),
        DateTime(2026, 11, 5),
        DateTime(2026, 12, 5),
      ]);
      expect(state.snapshot.available, 2600);

      final data = await reload();
      expect(data.upcoming.map((c) => c.billId).toSet(), {
        data.bills.single.id,
      });
      expect(data.bills.single.name, 'Rent');
      expect(data.bills.single.firstDue, DateTime(2026, 10, 5));
    });

    test('each month is paid or skipped on its own', () async {
      await start(semester);
      final months = state.comingUp;
      state.payUpcomingCost(months[0].id);
      state.deleteUpcomingCost(months[1].id); // skip November
      expect(state.comingUp.map((c) => c.id), [months[2].id]);
      expect(state.bills, hasLength(1));

      final data = await reload();
      expect(data.upcoming.map((c) => c.id), [months[2].id]);
      expect(data.bills, hasLength(1));
    });

    test('stopping it removes this month and later ones', () async {
      await start(semester);
      final months = state.comingUp;
      state.payUpcomingCost(months[0].id);
      state.deleteUpcomingCost(months[1].id, andLater: true);
      expect(state.comingUp, isEmpty);
      expect(state.bills, isEmpty);

      final data = await reload();
      expect(data.upcoming, isEmpty);
      expect(data.bills, isEmpty);
      expect(data.expenses.single.note, 'Rent'); // October's payment stays
    });

    test('a longer term reserves the months it gained', () async {
      await start(semester);
      state.updateTerm(
        Term(
          name: semester.name,
          start: semester.start,
          end: DateTime(2027, 1, 15),
          startingBalance: semester.startingBalance,
        ),
      );
      expect(state.comingUp.last.dueDate, DateTime(2027, 1, 5));
      expect((await reload()).upcoming, hasLength(4));
    });

    test('a monthly budget reserves it again each new month', () async {
      await start(
        Term(
          name: 'October',
          start: DateTime(2026, 10, 1),
          end: DateTime(2026, 10, 31),
          startingBalance: 2000,
          period: BudgetPeriod.monthly,
        ),
      );
      expect(state.comingUp.single.dueDate, DateTime(2026, 10, 5));
      state.payUpcomingCost(state.comingUp.single.id);

      clock = DateTime(2026, 12, 2, 9); // November skipped
      state.startNewMonthIfDue();
      expect(state.term.name, 'December');
      // November's rent wasn't marked paid, so it's still reserved.
      expect(state.comingUp.map((c) => c.dueDate), [
        DateTime(2026, 11, 5),
        DateTime(2026, 12, 5),
      ]);

      final data = await reload();
      expect(data.upcoming, hasLength(2));
      expect(data.bills, hasLength(1));
    });

    test('a new semester stops repeating bills', () async {
      await start(semester);
      state.startTerm(
        Term(
          name: 'Spring term',
          start: DateTime(2026, 10, 2),
          end: DateTime(2027, 5, 1),
          startingBalance: 100,
        ),
        const [],
      );
      expect(state.bills, isEmpty);
      final data = await reload();
      expect(data.bills, isEmpty);
      expect(data.upcoming, isEmpty);
    });
  });

  test('history lists finished terms and months, never the demo', () async {
    var clock = now;
    // The database stamps when a term ends, so it shares the app's clock.
    var repo = DriftBudgetRepository(
      RunwayDatabase(NativeDatabase(file)),
      clock: () => clock,
    );
    open.add(repo);
    final state = AppState(
      repository: repo,
      data: await repo.load(),
      clock: () => clock,
    );
    expect(await state.history(), isEmpty); // only the demo so far

    state.startTerm(
      Term(
        name: 'Summer',
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 30),
        startingBalance: 300,
      ),
      const [],
    );
    state.addExpense(amount: 20, category: ExpenseCategory.fun, isNeed: false);
    state.addExpense(
      amount: 5,
      category: ExpenseCategory.coffee,
      isNeed: false,
    );
    // Deleted, so not part of history.
    state.deleteExpense(state.allExpenses.singleWhere((e) => e.amount == 5).id);
    expect(await state.history(), isEmpty); // Summer is still current

    state.startTerm(
      Term(
        name: 'October',
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 31),
        startingBalance: 900,
        period: BudgetPeriod.monthly,
      ),
      const [],
    );
    state.addIncome(
      name: 'Job',
      amount: 100,
      frequency: IncomeFrequency.weekly,
      firstDate: DateTime(2026, 10, 2),
    );
    state.addExpense(
      amount: 40,
      category: ExpenseCategory.groceries,
      isNeed: true,
    );
    clock = DateTime(2026, 11, 3, 9);
    state.startNewMonthIfDue();

    // Read right away: history waits for the saves already in line.
    final past = await state.history();
    expect(past.map((p) => p.term.name), ['October', 'Summer']);
    final october = past.first;
    expect(october.term.period, BudgetPeriod.monthly);
    expect(october.expenses.map((e) => e.amount), [40]);
    expect(october.incomes.single.name, 'Job');
    expect(summarize(october).left, 1360); // 900 + 5 paydays − 40
    expect(past.last.expenses.map((e) => e.amount), [20]);

    repo = await reopen(repo);
    expect((await repo.history()).map((p) => p.term.name), [
      'October',
      'Summer',
    ]);
  });

  test('edited, deleted and restored expenses survive reopening', () async {
    var repo = openRepo();
    await repo.load();
    await repo.addExpense(expense('fix', 20, note: 'Typo'));
    await repo.addExpense(expense('gone', 5));
    await repo.addExpense(expense('back', 8));
    await repo.updateExpense(
      Expense(
        id: 'fix',
        amount: 2,
        category: ExpenseCategory.coffee,
        isNeed: false,
        date: now, // ignored: the original date stays
        note: 'Latte',
      ),
    );
    await repo.deleteExpense('gone');
    await repo.deleteExpense('back');
    await repo.restoreExpense('back');

    repo = await reopen(repo);
    final expenses = (await repo.load()).expenses;
    final fixed = expenses.singleWhere((e) => e.id == 'fix');
    expect(fixed.amount, 2);
    expect(fixed.category, ExpenseCategory.coffee);
    expect(fixed.isNeed, isFalse);
    expect(fixed.note, 'Latte');
    expect(fixed.date, now.add(const Duration(minutes: 5)));
    expect(expenses.map((e) => e.id), isNot(contains('gone')));
    expect(expenses.map((e) => e.id), contains('back'));
  });

  test('the app lock setting and your name survive reopening', () async {
    var repo = openRepo();
    expect((await repo.load()).appLock, isFalse);
    final state = AppState(
      repository: repo,
      data: await repo.load(),
      user: const UserProfile(name: 'Alex'),
      clock: () => now,
    );
    state.setAppLock(true);
    state.rename('Alexis');
    await pumpEventQueue(times: 100);

    repo = await reopen(repo);
    expect((await repo.load()).appLock, isTrue);
    expect((await repo.currentUser())?.name, 'Alexis');
  });

  group('when a save fails', () {
    late _FlakyRepository repo;
    late AppState state;
    late List<SaveProblem> problems;

    setUp(() async {
      repo = _FlakyRepository(
        RunwayDatabase(NativeDatabase(file)),
        clock: () => now,
      );
      state = AppState(
        repository: repo,
        data: await repo.load(),
        clock: () => now,
      );
      problems = [];
      state.problems.listen(problems.add);
    });

    tearDown(() async {
      state.dispose();
      await repo.close();
    });

    test('the change is undone and the user is told', () async {
      final before = state.allExpenses.length;
      final safe = state.snapshot.safeToSpendToday;
      repo.failWrites = true;
      state.addExpense(
        amount: 40,
        category: ExpenseCategory.fun,
        isNeed: false,
      );
      expect(state.allExpenses.length, before + 1); // optimistic

      await pumpEventQueue(times: 100);
      expect(state.allExpenses.length, before);
      expect(state.snapshot.safeToSpendToday, closeTo(safe, 1e-9));
      expect(problems, [SaveProblem.undone]);
    });

    test('changes that did save are kept', () async {
      state.addExpense(
        amount: 3,
        category: ExpenseCategory.coffee,
        isNeed: false,
      );
      // Saves run in order after the call, so pick the failure by amount.
      repo.failAmount = 40;
      state.addExpense(
        amount: 40,
        category: ExpenseCategory.fun,
        isNeed: false,
      );
      state.addExpense(
        amount: 7,
        category: ExpenseCategory.transit,
        isNeed: true,
      );

      await pumpEventQueue(times: 100);
      final amounts = state.recentExpenses(3).map((e) => e.amount);
      expect(amounts, containsAll([3, 7]));
      expect(amounts, isNot(contains(40)));
      expect(problems, [SaveProblem.undone]);
    });
  });
}

/// Saves to a real database, but [failWrites] makes new expenses fail to
/// save, like a full disk would; [failAmount] fails only that amount.
class _FlakyRepository extends DriftBudgetRepository {
  _FlakyRepository(super.db, {super.clock});

  bool failWrites = false;
  double? failAmount;

  @override
  Future<void> addExpense(Expense expense) async {
    if (failWrites || expense.amount == failAmount) {
      throw StateError('disk full');
    }
    await super.addExpense(expense);
  }
}
