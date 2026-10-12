import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/app_state.dart';
import 'package:runway/app/auth.dart';
import 'package:runway/app/device_auth.dart';
import 'package:runway/app/models.dart';
// import 'package:runway/app/purchase_link.dart';
import 'package:runway/app/repository.dart';
import 'package:runway/main.dart';
import 'package:runway/screens/add_income_sheet.dart';
import 'package:runway/screens/quick_add_sheet.dart';
import 'package:runway/screens/settings_screen.dart';
import 'package:runway/widgets/celebrations.dart';
import 'package:runway/widgets/expense_inputs.dart';
import 'package:runway/widgets/form_fields.dart';
import 'package:runway/widgets/mochi_takeoff.dart';
import 'package:runway/widgets/ph_icons.dart';

/// Pumps frame-by-frame for [d]. The app has endless ambient animations
/// (aurora, pet), so pumpAndSettle would never return.
Future<void> settle(
  WidgetTester tester, [
  Duration d = const Duration(seconds: 1),
]) async {
  const frame = Duration(milliseconds: 16);
  for (var t = Duration.zero; t < d; t += frame) {
    await tester.pump(frame);
  }
}

/// Scrolls [finder] to the middle of its scroll view, clear of the floating
/// nav bar that covers the bottom edge.
Future<void> centerOn(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
}

void main() {
  final now = DateTime(2026, 10, 2, 15);

  AppState buildState() => AppState(
    repository: MockBudgetRepository(now: now),
    data: MockBudgetRepository.seed(now),
    user: const UserProfile(name: 'Alex', email: 'alex@uni.edu'),
    clock: () => now,
  );

  test('logging an expense updates the snapshot and notifies', () {
    final state = buildState();
    final before = state.snapshot.safeToSpendToday;
    var notified = false;
    state.addListener(() => notified = true);
    state.addExpense(
      amount: 10,
      category: ExpenseCategory.coffee,
      isNeed: false,
    );
    expect(notified, isTrue);
    // Spending today moves money from "available" to "spentToday", so the
    // daily allowance holds and safe-to-spend drops by exactly the amount.
    expect(state.snapshot.safeToSpendToday, closeTo(before - 10, 1e-9));
    expect(state.recentExpenses(1).single.amount, 10);
  });

  test('splitting a bill adds IOUs and only your share as spending', () {
    final state = buildState();
    final spentBefore = state.snapshot.totalSpent;
    final splitsBefore = state.splits.length;
    final roommates = state.friends.take(2).toList();

    state.splitBill(
      description: 'Costco run',
      total: 90,
      roommates: roommates,
      category: ExpenseCategory.groceries,
      isNeed: true,
    );

    expect(state.splits.length, splitsBefore + 2);
    final added = state.splits.take(2);
    expect(added.map((s) => s.person), roommates.map((f) => f.name));
    expect(added.every((s) => s.theyOweYou && s.amount == 30), isTrue);
    expect(added.every((s) => s.note == 'Costco run'), isTrue);
    expect(state.snapshot.totalSpent, closeTo(spentBefore + 30, 1e-9));
    expect(state.recentExpenses(1).single.title, 'Costco run');
  });

  testWidgets('app boots and shows the home screen', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RunwayApp(state: buildState(), intro: false));
    // Infinite ambient animations (aurora, pet) mean pumpAndSettle never
    // settles; pump past the entrance animations instead.
    await settle(tester, const Duration(seconds: 2));

    expect(find.text('Safe to spend today'), findsOneWidget);
    expect(find.text('14 days short'), findsOneWidget);
    expect(find.text('Coming up'), findsOneWidget);

    await tester.tap(find.text('Squad'));
    await settle(tester, const Duration(seconds: 2));
    expect(find.text('No-delivery week'), findsOneWidget);
  });

  testWidgets('first run: setup replaces the demo term', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final demo = MockBudgetRepository.seed(now);
    final state = AppState(
      repository: MockBudgetRepository(now: now),
      data: BudgetData(
        term: demo.term,
        expenses: demo.expenses,
        upcoming: demo.upcoming,
        friends: demo.friends,
        splits: demo.splits,
        challengeStart: demo.challengeStart,
        needsSetup: true,
      ),
      user: const UserProfile(name: 'Alex', email: 'alex@uni.edu'),
      clock: () => now,
    );

    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);
    expect(find.text('Set up your semester'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Winter term');
    await tester.enterText(fields.at(1), '1500');
    await tester.tap(find.text('Pick date').first); // term end
    await settle(tester);
    await tester.tap(find.text('20'));
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(find.text('Oct 20, 2026'), findsOneWidget);

    await tester.enterText(fields.at(2), 'Concert');
    await tester.enterText(fields.at(3), '100');
    await tester.tap(find.text('Pick date')); // cost due date
    await settle(tester);
    await tester.tap(find.text('10'));
    await tester.tap(find.text('OK'));
    await settle(tester);
    await tester.tap(find.text('Add cost'));
    await settle(tester);
    expect(find.text('📌 Concert · Oct 10'), findsOneWidget);

    await tester.ensureVisible(find.text('Start my runway'));
    await tester.tap(find.text('Start my runway'));
    await settle(tester, const Duration(seconds: 2));

    expect(state.needsSetup, isFalse);
    expect(state.term.name, 'Winter term');
    expect(state.term.end, DateTime(2026, 10, 20));
    expect(state.recentExpenses(), isEmpty);
    expect(state.snapshot.available, 1400);
    expect(find.text('Safe to spend today'), findsOneWidget);
    expect(find.text('Concert'), findsOneWidget);
    expect(
      find.text('Nothing logged yet. Tap + to add your first expense.'),
      findsOneWidget,
    );
  });

  testWidgets('first run: a monthly budget runs to the end of the month', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final demo = MockBudgetRepository.seed(now);
    final state = AppState(
      repository: MockBudgetRepository(now: now),
      data: BudgetData(
        term: demo.term,
        expenses: demo.expenses,
        upcoming: demo.upcoming,
        friends: demo.friends,
        splits: demo.splits,
        challengeStart: demo.challengeStart,
        needsSetup: true,
      ),
      user: const UserProfile(name: 'Alex'),
      clock: () => now,
    );

    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);
    await tester.tap(find.text('Monthly'));
    await settle(tester);
    expect(find.text('Set up your month'), findsOneWidget);
    expect(find.text('Term name'), findsNothing);
    expect(find.text('Oct 31, then monthly'), findsOneWidget);

    // No name or end date to fill in: the money is the first field.
    await tester.enterText(find.byType(TextField).first, '900');
    await settle(tester);
    await tester.ensureVisible(find.text('Start my runway'));
    await tester.tap(find.text('Start my runway'));
    await settle(tester, const Duration(seconds: 2));

    expect(state.term.name, 'October');
    expect(state.term.period, BudgetPeriod.monthly);
    expect(state.term.start, DateTime(2026, 10, 2));
    expect(state.term.end, DateTime(2026, 10, 31));
    expect(state.term.startingBalance, 900);
    expect(
      find.textContaining('Month ends Oct 31', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('coach chip produces a verdict after typing', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RunwayApp(state: buildState(), intro: false));
    await settle(tester, const Duration(seconds: 1));
    await tester.tap(find.text('Coach'));
    await settle(tester, const Duration(seconds: 1));

    await tester.tap(find.text('Dinner out \$25'));
    await settle(tester, const Duration(milliseconds: 100));
    expect(find.bySemanticsLabel('Coach is typing'), findsOneWidget);

    await settle(tester, const Duration(seconds: 2));
    expect(find.text('Yes, if you trade for it'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('quick add logs an expense and extends the streak', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // A state with nothing logged today yet.
    final data = MockBudgetRepository.seed(now);
    final state = AppState(
      repository: MockBudgetRepository(now: now),
      data: BudgetData(
        term: data.term,
        expenses: data.expenses.where((e) => e.id != 'seed-today').toList(),
        upcoming: data.upcoming,
        friends: data.friends,
        splits: data.splits,
        challengeStart: data.challengeStart,
      ),
      user: const UserProfile(name: 'Alex', email: 'alex@uni.edu'),
      clock: () => now,
    );
    final streak = state.streak;

    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester, const Duration(seconds: 1));
    await tester.tap(find.bySemanticsLabel('Add expense'));
    await settle(tester, const Duration(seconds: 1));

    await tester.tap(
      find.textContaining('Groceries', findRichText: true).first,
    );
    await settle(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text('Log \$38.00'));
    await settle(tester, const Duration(seconds: 1));

    expect(state.streak, streak + 1);
    expect(state.snapshot.spentToday, 38);
    expect(find.text('Quick add'), findsNothing);
  });

  testWidgets('every screen lays out on a small phone', (tester) async {
    tester.view.physicalSize = const Size(750, 1334); // iPhone SE
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RunwayApp(state: buildState(), intro: false));
    await settle(tester);
    for (final tab in ['Coach', 'Squad', 'Home']) {
      await tester.tap(find.text(tab).last);
      await settle(tester);
    }
    await tester.tap(find.bySemanticsLabel('Add expense'));
    await settle(tester);
    expect(find.text('Quick add'), findsOneWidget);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.text('Quick add'))).pop();
    await settle(tester);

    await centerOn(tester, find.text('Add money'));
    await tester.tap(find.text('Add money'));
    await settle(tester);
    expect(find.text('Money coming in'), findsOneWidget);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.text('Money coming in'))).pop();
    await settle(tester);

    await tester.ensureVisible(find.text('A'));
    await settle(tester);
    await tester.tap(find.text('A')); // avatar opens Settings
    await settle(tester);
    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching tabs fully hides the previous tab', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RunwayApp(state: buildState(), intro: false));
    await settle(tester);

    double opacityOf(Finder f) => tester
        .widget<AnimatedOpacity>(
          find.ancestor(of: f, matching: find.byType(AnimatedOpacity)).first,
        )
        .opacity;
    double renderedOpacityOf(Finder f) => tester
        .renderObject<RenderAnimatedOpacity>(
          find.ancestor(of: f, matching: find.byType(AnimatedOpacity)).first,
        )
        .opacity
        .value;

    final home = find.text('Safe to spend today');
    for (final tab in ['Coach', 'Squad']) {
      await tester.tap(find.text(tab).last);
      await settle(tester);
      expect(opacityOf(home), 0);
      expect(
        renderedOpacityOf(home),
        0,
        reason: 'Home still visible behind $tab',
      );
    }
  });

  testWidgets('quick add saves a note and any category', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = buildState();
    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Add expense'));
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'Uber to airport');
    await tester.tap(find.text('2'));
    await tester.tap(find.text('7'));
    await settle(tester, const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text('Uber / ride'),
      120,
      scrollable: find.descendant(
        of: find.byType(CategoryPicker),
        matching: find.byType(Scrollable),
      ),
    );
    await settle(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Uber / ride'));
    await settle(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Log \$27.00'));
    await settle(tester);

    final e = state.recentExpenses(1).single;
    expect(e.title, 'Uber to airport');
    expect(e.category, ExpenseCategory.rideshare);
    expect(e.amount, 27);
  });

  // Apple Pay logging is switched off for now.
  // testWidgets('an Apple Pay purchase opens Quick Add pre-filled', (
  //   tester,
  // ) async {
  //   tester.view.physicalSize = const Size(1290, 2796);
  //   tester.view.devicePixelRatio = 3;
  //   addTearDown(tester.view.reset);

  //   // Arrives before Home is on screen, as when the link launches the app.
  //   final state = buildState();
  //   state.pendingPurchase.value = const ApplePayPurchase(
  //     amount: 6.45,
  //     merchant: 'Blue Bottle Coffee',
  //   );
  //   await tester.pumpWidget(RunwayApp(state: state, intro: false));
  //   await settle(tester);

  //   expect(find.text('From Apple Pay'), findsOneWidget);
  //   expect(find.text('Blue Bottle Coffee'), findsOneWidget);
  //   expect(state.pendingPurchase.value, isNull);
  //   await tester.tap(find.text('Log \$6.45'));
  //   await settle(tester);

  //   final e = state.recentExpenses(1).single;
  //   expect(e.title, 'Blue Bottle Coffee');
  //   expect(e.amount, 6.45);

  //   // And while the app is already open; a missing amount is left to type.
  //   state.pendingPurchase.value = const ApplePayPurchase(merchant: 'CVS');
  //   await settle(tester);
  //   expect(find.text('From Apple Pay'), findsOneWidget);
  //   expect(find.text('CVS'), findsOneWidget);
  //   expect(find.text('Enter an amount'), findsOneWidget);
  // });

  test('money due later only counts once its day arrives', () {
    var clock = now;
    final state = AppState(
      repository: MockBudgetRepository(now: now),
      data: MockBudgetRepository.seed(now),
      clock: () => clock,
    );
    final before = state.snapshot.balance;
    state.addIncome(
      name: 'Scholarship',
      amount: 500,
      frequency: IncomeFrequency.once,
      firstDate: DateTime(2026, 10, 5),
    );
    expect(state.snapshot.balance, before);
    expect(state.nextIncome?.income.name, 'Scholarship');

    clock = DateTime(2026, 10, 5, 9);
    state.addExpense(
      amount: 1,
      category: ExpenseCategory.coffee,
      isNeed: false,
    );
    expect(state.snapshot.received, 500);
    expect(state.snapshot.balance, closeTo(before + 500 - 1, 1e-9));
    expect(state.nextIncome, isNull);
  });

  test('paying a reserved cost keeps today\'s budget steady', () {
    final state = buildState();
    final safe = state.snapshot.safeToSpendToday;
    final available = state.snapshot.available;
    final phone = state.comingUp.first;

    state.payUpcomingCost(phone.id);

    expect(state.comingUp.map((c) => c.id), isNot(contains(phone.id)));
    expect(state.snapshot.safeToSpendToday, closeTo(safe, 1e-9));
    expect(state.snapshot.available, closeTo(available, 1e-9));
    final logged = state.recentExpenses(1).single;
    expect(logged.title, phone.name);
    expect(logged.planned, isTrue);
  });

  testWidgets('adding money on Home raises safe-to-spend today', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final state = buildState();
    final safe = state.snapshot.safeToSpendToday;

    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);
    await centerOn(tester, find.text('Add money'));
    await tester.tap(find.text('Add money'));
    await settle(tester);
    expect(find.text('Money coming in'), findsOneWidget);

    final fields = find.descendant(
      of: find.byType(AddIncomeSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'Tutoring');
    await tester.enterText(fields.at(1), '70');
    await settle(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Add \$70.00'));
    await settle(tester);

    expect(state.incomes.single.name, 'Tutoring');
    expect(state.snapshot.received, 70);
    expect(
      state.snapshot.safeToSpendToday,
      closeTo(safe + 70 / state.snapshot.daysLeft, 1e-9),
    );
    expect(find.text('Tutoring'), findsOneWidget);
  });

  testWidgets('settings saves term edits and can erase everything', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final state = buildState();

    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);
    await tester.tap(find.text('A')); // avatar opens Settings
    await settle(tester);

    expect(find.text('Saved'), findsOneWidget);
    // The first field is your name; the term name comes next.
    final termName = find.byType(TextField).at(1);
    await tester.enterText(termName, '');
    await settle(tester, const Duration(milliseconds: 300));
    expect(find.text('Give the term a name.'), findsOneWidget);
    await tester.enterText(termName, 'Fall 2026');
    await settle(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Save changes'));
    await settle(tester);
    expect(state.term.name, 'Fall 2026');
    expect(find.text('Saved'), findsOneWidget);

    final settingsList = find
        .descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Erase everything on this phone'),
      200,
      scrollable: settingsList,
    );
    await tester.ensureVisible(find.text('Erase everything on this phone'));
    await settle(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Erase everything on this phone'));
    await settle(tester);
    expect(find.text('Erase everything?'), findsOneWidget);
    await tester.tap(find.text('Erase everything'));
    await settle(tester, const Duration(seconds: 2));

    expect(state.user, isNull);
    expect(find.byType(LogoMark), findsOneWidget);
  });

  testWidgets('settings adds a monthly bill and can stop it', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final state = buildState();
    final available = state.snapshot.available;

    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);
    await tester.tap(find.text('A'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Every month'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await settle(tester, const Duration(milliseconds: 300));

    final fields = find.descendant(
      of: find.byType(AddCostForm),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'Gym');
    await tester.enterText(fields.at(1), '30');
    await tester.tap(find.text('Pick date'));
    await settle(tester);
    await tester.tap(find.text('10'));
    await tester.tap(find.text('OK'));
    await settle(tester);
    await tester.tap(find.text('Every month'));
    await tester.tap(find.text('Add cost'));
    await settle(tester);

    // Oct 10, Nov 10 and Dec 10 fall before the term ends on Dec 11.
    expect(state.bills.single.name, 'Gym');
    expect(state.comingUp.where((c) => c.repeats), hasLength(3));
    expect(state.snapshot.available, closeTo(available - 90, 1e-9));

    final row = find.text('📌 Gym · Oct 10 · monthly');
    await tester.ensureVisible(row);
    await tester.tap(row);
    await settle(tester);
    expect(find.text('Skip just this month'), findsOneWidget);
    await tester.tap(find.text('Stop this bill'));
    await settle(tester);

    expect(state.bills, isEmpty);
    expect(state.comingUp.where((c) => c.repeats), isEmpty);
    expect(state.snapshot.available, closeTo(available, 1e-9));
  });

  test('editing and deleting an expense updates the numbers', () {
    final state = buildState();
    final safe = state.snapshot.safeToSpendToday;
    final coffee = state.recentExpenses(1).single; // today's $4.50

    state.updateExpense(coffee.copyWith(amount: 10, note: () => 'Big latte'));
    expect(state.snapshot.safeToSpendToday, closeTo(safe - 5.5, 1e-9));
    expect(state.recentExpenses(1).single.title, 'Big latte');

    final removed = state.deleteExpense(coffee.id)!;
    expect(state.snapshot.safeToSpendToday, closeTo(safe + 4.5, 1e-9));
    expect(state.deleteExpense(coffee.id), isNull);

    state.restoreExpense(removed);
    state.restoreExpense(removed); // a second Undo does nothing
    expect(state.allExpenses.where((e) => e.id == coffee.id), hasLength(1));
    expect(state.snapshot.safeToSpendToday, closeTo(safe - 5.5, 1e-9));
  });

  testWidgets('tap a recent expense to edit it, delete it, and undo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final state = buildState();
    final count = state.allExpenses.length;

    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);
    final coffee = find.text('Coffee').first;
    await centerOn(tester, coffee);
    await tester.tap(coffee);
    await settle(tester);
    await tester.tap(find.text('Edit'));
    await settle(tester);
    expect(find.text('Edit expense'), findsOneWidget);
    expect(find.text('Save \$4.50'), findsOneWidget);
    await tester.tap(find.byIcon(PhIcons.backspace));
    await tester.tap(find.byIcon(PhIcons.backspace));
    await settle(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Save \$4.00'));
    await settle(tester);
    expect(state.recentExpenses(1).single.amount, 4);
    expect(state.allExpenses.length, count);

    await centerOn(tester, find.text('Coffee').first);
    await tester.tap(find.text('Coffee').first);
    await settle(tester);
    await tester.tap(find.text('Delete expense'));
    await settle(tester);
    expect(state.allExpenses.length, count - 1);
    expect(find.text('Deleted Coffee'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(state.allExpenses.length, count);
  });

  testWidgets('see all lists every expense by day and can delete', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final state = buildState();
    final count = state.allExpenses.length;

    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);
    await centerOn(tester, find.text('See all'));
    await tester.tap(find.text('See all'));
    await settle(tester);

    expect(find.text('All expenses'), findsOneWidget);
    expect(find.textContaining('$count expenses'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);

    await tester.tap(find.text('Coffee').first);
    await settle(tester);
    await tester.tap(find.text('Delete expense'));
    await settle(tester);
    expect(state.allExpenses.length, count - 1);
    expect(find.textContaining('${count - 1} expenses'), findsOneWidget);
  });

  testWidgets('a failed save shows a message', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final state = AppState(
      repository: _FailingRepository(now: now),
      data: MockBudgetRepository.seed(now),
      user: const UserProfile(name: 'Alex', email: 'alex@uni.edu'),
      clock: () => now,
    );

    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);
    state.addExpense(amount: 9, category: ExpenseCategory.fun, isNeed: false);
    await settle(tester);

    expect(find.text(SaveProblem.undone.message), findsOneWidget);
    // The failure is still reported for debugging, not swallowed.
    expect(tester.takeException(), isA<StateError>());
  });

  testWidgets('squad split-a-bill sheet creates IOUs', (tester) async {
    tester.view.physicalSize = const Size(750, 1334); // small phone
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final state = buildState();
    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);
    await tester.tap(find.text('Squad').last);
    await settle(tester);
    await tester.ensureVisible(find.text('Split a bill'));
    await settle(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Split a bill'));
    await settle(tester);

    await tester.enterText(find.byType(TextField).at(0), 'Takeout feast');
    await tester.enterText(find.byType(TextField).at(1), '36');
    await tester.tap(find.text('🦊 Maya'));
    await tester.tap(find.text('🐸 Jules'));
    await settle(tester, const Duration(milliseconds: 400));
    expect(find.text('Maya owes you'), findsOneWidget);
    expect(find.text('\$12.00'), findsNWidgets(3));

    await tester.ensureVisible(find.text('Split \$36.00'));
    await settle(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Split \$36.00'));
    await settle(tester, const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
    expect(
      state.splits.where((s) => s.note == 'Takeout feast').map((s) => s.person),
      unorderedEquals(['Maya', 'Jules']),
    );
    expect(find.text('Split a bill'), findsOneWidget); // sheet closed
  });

  group('welcome', () {
    AppState fresh() => AppState(
      repository: MockBudgetRepository(now: now),
      data: MockBudgetRepository.seed(now),
      clock: () => now,
    );

    Future<void> boot(WidgetTester tester, AppState state) async {
      tester.view.physicalSize = const Size(750, 1334); // small phone
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(RunwayApp(state: state, intro: false));
      await settle(tester);
    }

    testWidgets('asks only for a name, then reveals home', (tester) async {
      final state = fresh();
      await boot(tester, state);
      expect(find.byType(LogoMark), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // no email, no password

      await tester.enterText(find.byType(TextField), '  Maya ');
      await tester.tap(find.text('Get started'));
      await settle(tester, const Duration(seconds: 3));

      expect(tester.takeException(), isNull);
      expect(state.user?.name, 'Maya');
      expect(state.user?.email, isEmpty);
      expect(find.text('Hey, Maya'), findsOneWidget);
      expect(find.byType(LogoMark), findsNothing); // welcome route is gone
    });

    testWidgets('an empty name shows an error and stays put', (tester) async {
      final state = fresh();
      await boot(tester, state);

      await tester.tap(find.text('Get started'));
      await settle(tester);

      expect(find.text('What should we call you?'), findsOneWidget);
      expect(state.user, isNull);
    });

    testWidgets('your name can be changed in settings', (tester) async {
      final semantics = tester.ensureSemantics();
      final state = buildState();
      await boot(tester, state);

      await tester.tap(find.text('A')); // avatar initial
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Alexis');
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.bySemanticsLabel('Save name'));
      await settle(tester);

      expect(state.user?.name, 'Alexis');
      expect(find.text('Sign out'), findsNothing);
      semantics.dispose();
    });
  });

  test('names are required and kept short', () {
    expect(validateName('Sam'), isNull);
    expect(validateName('   '), isNotNull);
    expect(validateName('x' * 31), isNotNull);
  });

  group('app lock', () {
    late _FakeDeviceAuth deviceAuth;
    late DateTime clock;

    AppState lockedState({bool lockOn = true}) {
      final demo = MockBudgetRepository.seed(now);
      return AppState(
        repository: MockBudgetRepository(now: now),
        data: BudgetData(
          term: demo.term,
          expenses: demo.expenses,
          upcoming: demo.upcoming,
          friends: demo.friends,
          splits: demo.splits,
          challengeStart: demo.challengeStart,
          appLock: lockOn,
        ),
        user: const UserProfile(name: 'Alex'),
        deviceAuth: deviceAuth,
        clock: () => clock,
      );
    }

    Future<void> boot(WidgetTester tester, AppState state) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(RunwayApp(state: state, intro: false));
      await settle(tester);
    }

    Future<void> goAway(WidgetTester tester, Duration away) async {
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      clock = clock.add(away);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
    }

    setUp(() {
      deviceAuth = _FakeDeviceAuth();
      clock = now;
    });

    testWidgets('opens locked and asks for Face ID right away', (tester) async {
      deviceAuth.result = DeviceAuthResult.failed; // cancelled
      await boot(tester, lockedState());

      expect(deviceAuth.prompts, 1);
      expect(find.text('Runway is locked'), findsOneWidget);

      deviceAuth.result = DeviceAuthResult.success;
      await tester.tap(find.text('Unlock'));
      await settle(tester);
      expect(find.text('Runway is locked'), findsNothing);
      expect(find.text('Safe to spend today'), findsOneWidget);
    });

    testWidgets('locks again after a minute away, not after a few seconds', (
      tester,
    ) async {
      await boot(tester, lockedState()); // unlocks: fake says success
      expect(find.text('Runway is locked'), findsNothing);

      deviceAuth.result = DeviceAuthResult.failed;
      await goAway(tester, const Duration(seconds: 20));
      expect(find.text('Runway is locked'), findsNothing);

      await goAway(tester, const Duration(minutes: 2));
      expect(find.text('Runway is locked'), findsOneWidget);
      expect(deviceAuth.prompts, 2);
    });

    testWidgets('balances are covered in the app switcher', (tester) async {
      await boot(tester, lockedState(lockOn: false));
      expect(find.byType(LogoMark), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byType(LogoMark), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byType(LogoMark), findsNothing);
      expect(deviceAuth.prompts, 0); // lock is off
    });

    testWidgets('a phone without a passcode is never locked out', (
      tester,
    ) async {
      deviceAuth.result = DeviceAuthResult.unavailable;
      await boot(tester, lockedState());
      expect(find.text('Runway is locked'), findsNothing);
    });

    testWidgets('setup offers the lock and turns it on after Face ID', (
      tester,
    ) async {
      final demo = MockBudgetRepository.seed(now);
      final state = AppState(
        repository: MockBudgetRepository(now: now),
        data: BudgetData(
          term: demo.term,
          expenses: demo.expenses,
          upcoming: demo.upcoming,
          friends: demo.friends,
          splits: demo.splits,
          challengeStart: demo.challengeStart,
          needsSetup: true,
        ),
        user: const UserProfile(name: 'Alex'),
        deviceAuth: deviceAuth,
        clock: () => clock,
      );
      await boot(tester, state);
      expect(find.text('Lock Runway'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Winter term');
      await tester.enterText(fields.at(1), '1500');
      await tester.tap(find.text('Pick date').first);
      await settle(tester);
      await tester.tap(find.text('20'));
      await tester.tap(find.text('OK'));
      await settle(tester);
      await tester.ensureVisible(find.text('Start my runway'));
      await tester.tap(find.text('Start my runway'));
      await settle(tester, const Duration(seconds: 2));

      expect(deviceAuth.prompts, 1);
      expect(state.appLockEnabled, isTrue);
      expect(find.text('Safe to spend today'), findsOneWidget);
    });

    testWidgets('turning the lock on in settings asks for Face ID first', (
      tester,
    ) async {
      final state = lockedState(lockOn: false);
      await boot(tester, state);
      await tester.tap(find.text('A'));
      await settle(tester);

      deviceAuth.result = DeviceAuthResult.failed;
      await tester.tap(find.byType(Switch));
      await settle(tester);
      expect(state.appLockEnabled, isFalse);

      deviceAuth.result = DeviceAuthResult.success;
      await tester.tap(find.byType(Switch));
      await settle(tester);
      expect(state.appLockEnabled, isTrue);
      expect(deviceAuth.prompts, 2);
    });
  });

  group('motion', () {
    Future<void> bootHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(RunwayApp(state: buildState(), intro: false));
      await settle(tester);
    }

    Future<void> logCoffee(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Add expense'));
      await settle(tester);
      await tester.tap(
        find
            .descendant(
              of: find.byType(QuickAddSheet),
              matching: find.text('Coffee'),
            )
            .first,
      );
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Log \$4.50'));
    }

    testWidgets('logging tosses a coin into the ring, which pulses', (
      tester,
    ) async {
      await bootHome(tester);
      final pulses = ringPulse.value;
      await logCoffee(tester);
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text(r'$'), findsWidgets); // coin in flight
      await settle(tester, const Duration(seconds: 1));
      expect(ringPulse.value, pulses + 1);
      expect(find.text(r'$'), findsNothing); // coin landed and removed
      expect(tester.takeException(), isNull);
    });

    testWidgets('logging from another tab brings you back to Home', (
      tester,
    ) async {
      await bootHome(tester);
      await tester.tap(find.text('Squad').last);
      await settle(tester);
      await logCoffee(tester);
      await settle(tester, const Duration(seconds: 2));
      final home = tester.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.text('Safe to spend today'),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(home.opacity, 1);
    });

    testWidgets('compact bar slides in once the greeting scrolls away', (
      tester,
    ) async {
      await bootHome(tester);
      expect(find.text('Hey, Alex'), findsOneWidget); // only the big one
      await tester.drag(
        find.text('Safe to spend today'),
        const Offset(0, -300),
      );
      await settle(tester);
      expect(find.text('Hey, Alex'), findsNWidgets(2));
      expect(find.textContaining('Safe today'), findsOneWidget);
    });

    testWidgets('Reduce Motion: no coin, but the ring still pulses', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await bootHome(tester);
      final pulses = ringPulse.value;
      await logCoffee(tester);
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text(r'$'), findsNothing);
      expect(ringPulse.value, pulses + 1);
    });
  });
}

/// Nothing ever saves.
class _FailingRepository extends MockBudgetRepository {
  _FailingRepository({super.now});

  @override
  Future<void> addExpense(Expense expense) async =>
      throw StateError('disk full');
}

/// Face ID that answers whatever the test sets.
class _FakeDeviceAuth implements DeviceAuth {
  DeviceAuthResult result = DeviceAuthResult.success;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => result != DeviceAuthResult.unavailable;

  @override
  Future<DeviceAuthResult> authenticate(String reason) async {
    prompts++;
    return result;
  }
}
