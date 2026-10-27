import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/app_state.dart';
import 'package:runway/app/auth.dart';
import 'package:runway/app/budget_sync.dart';
import 'package:runway/app/device_auth.dart';
import 'package:runway/app/format.dart';
import 'package:runway/app/models.dart';
import 'package:runway/app/reminders.dart';
import 'package:runway/app/voice_inbox.dart';
// import 'package:runway/app/purchase_link.dart';
import 'package:runway/app/repository.dart';
import 'package:runway/app/split_math.dart';
import 'package:runway/app/squad.dart';
import 'package:runway/main.dart';
import 'package:runway/screens/add_income_sheet.dart';
import 'package:runway/screens/edit_cost_sheet.dart';
import 'package:runway/screens/friends_sheets.dart';
import 'package:runway/screens/history_screen.dart';
import 'package:runway/screens/quick_add_sheet.dart';
import 'package:runway/screens/settings_screen.dart';
import 'package:runway/widgets/celebrations.dart';
import 'package:runway/widgets/expense_inputs.dart';
import 'package:runway/widgets/form_fields.dart';
import 'package:runway/widgets/list_row.dart';
import 'package:runway/widgets/mochi_takeoff.dart';
import 'package:runway/widgets/ph_icons.dart';

import 'fake_budget_server.dart';

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

  test('expenses said to Siri are filed with a guessed category', () {
    final state = buildState();
    final vape = state.addCustomCategory(name: 'Vape', emoji: '💨');
    VoiceEntry said(
      double amount,
      String what,
      DateTime at, [
      String? c,
      String? own,
    ]) => (amount: amount, what: what, at: at, category: c, custom: own);
    state.addSpokenExpenses([
      said(12.499, '12.50 at chipotle', now.subtract(const Duration(hours: 2))),
      said(9, 'Vape pods', now, 'shopping'),
      said(30, 'something', DateTime(2020)),
      said(-4, 'bad', now),
      said(6, 'an Uber', now, 'rideshare'),
      said(7, 'Pods', now, 'shopping', 'vape'),
    ]);
    final added = state.addedFromSiri.value!;
    expect(added, hasLength(5));
    expect(added[4].custom?.id, vape.id);
    expect(added[3].category, ExpenseCategory.rideshare);
    expect(added[3].note, 'Uber');
    expect(added[0].amount, 12.5);
    expect(added[0].note, 'Chipotle');
    expect(added[0].category, ExpenseCategory.eatingOut);
    expect(added[0].date, now.subtract(const Duration(hours: 2)));
    expect(added[1].custom?.id, vape.id);
    expect(added[2].category, ExpenseCategory.other);
    // Said before this term began, so it counts from now.
    expect(added[2].date, now);
    expect(
      state.recentExpenses(5).map((e) => e.id),
      containsAll(added.map((e) => e.id)),
    );
  });

  test('Siri gets today\'s numbers and the last week of spending', () {
    final state = buildState();
    state.addExpense(
      amount: 7,
      category: ExpenseCategory.coffee,
      isNeed: false,
    );
    final summary = state.siriSummary!;
    final s = state.snapshot;
    expect(summary['day'], '2026-10-02');
    expect(summary['safeToday'], closeTo(s.safeToSpendToday, 0.005));
    expect(summary['daysLeft'], s.daysLeft);
    final days = summary['days']! as Map<String, double>;
    expect(days['2026-10-02'], greaterThanOrEqualTo(7));
    expect(days.keys.every((k) => k.compareTo('2026-09-26') >= 0), isTrue);
    expect((summary['weekTop']! as List), isNotEmpty);
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

    await tester.enterText(fields.at(2), '150'); // save this semester
    await tester.enterText(fields.at(3), 'Concert');
    await tester.enterText(fields.at(4), '100');
    await tester.ensureVisible(find.text('Pick date'));
    await settle(tester, const Duration(milliseconds: 300));
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
    expect(state.term.savingsGoal, 150);
    expect(state.snapshot.available, 1250); // 1500 − 100 cost − 150 saved
    expect(state.offerSavingsGoal, isFalse); // setup already asked
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

    final state = buildState()..setSavingsGoal(80);
    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);
    await tester.tap(find.text('Savings').last);
    await settle(tester);
    await tester.tap(find.text('Change goal'));
    await settle(tester);
    expect(find.text('Save this semester'), findsOneWidget);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.text('Save this semester'))).pop();
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
    for (final tab in ['Savings', 'Coach', 'Squad']) {
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

  testWidgets('a repeat Other note becomes a one-tap category', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = buildState();
    state.addExpense(
      amount: 12,
      category: ExpenseCategory.other,
      isNeed: false,
      note: 'cigarettes',
    );
    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Add expense'));
    await settle(tester);

    // Logging it in Other again offers to make it a category.
    await tester.enterText(find.byType(TextField), 'Cigarettes');
    await settle(tester, const Duration(milliseconds: 300));
    expect(find.textContaining('Make it a category?'), findsOneWidget);
    await tester.tap(find.text('Make it'));
    await settle(tester);
    expect(find.text('New category'), findsOneWidget);
    await tester.tap(find.text('🚬'));
    await settle(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Add 🚬 Cigarettes'));
    await settle(tester);

    // Picked for this expense, and the earlier one moved into it too.
    await tester.tap(find.text('1'));
    await tester.tap(find.text('3'));
    await settle(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Log \$13.00'));
    await settle(tester);
    expect(state.customCategories.single.name, 'Cigarettes');
    expect(state.allExpenses.take(2).map((e) => e.custom?.name), [
      'Cigarettes',
      'Cigarettes',
    ]);

    // Next time it's a chip at the front, no typing needed.
    await tester.tap(find.bySemanticsLabel('Add expense'));
    await settle(tester);
    expect(find.text('Make it'), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(CategoryPicker),
        matching: find.text('Cigarettes'),
      ),
    );
    await tester.tap(find.text('9'));
    await settle(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Log \$9.00'));
    await settle(tester);
    final e = state.recentExpenses(1).single;
    expect(e.custom?.name, 'Cigarettes');
    expect(e.title, 'Cigarettes');
    expect(e.category, ExpenseCategory.other);
  });

  test('custom category names are checked and renames show everywhere', () {
    final state = buildState();
    expect(state.checkCategoryName('  '), isNotNull);
    expect(state.checkCategoryName('coffee'), isNotNull); // built-in
    final vape = state.addCustomCategory(name: ' Vape ', emoji: '💨x');
    expect(vape.name, 'Vape');
    expect(vape.emoji, '💨');
    expect(state.checkCategoryName('VAPE'), isNotNull);
    expect(state.checkCategoryName('Vape', editingId: vape.id), isNull);

    state.addExpense(
      amount: 8,
      category: ExpenseCategory.coffee, // ignored: it's filed under Vape
      isNeed: false,
      custom: vape,
    );
    expect(state.recentExpenses(1).single.category, ExpenseCategory.other);
    state.updateCustomCategory(vape.copyWith(name: 'Vaping'));
    expect(state.recentExpenses(1).single.title, 'Vaping');

    state.deleteCustomCategory(vape.id);
    expect(state.customCategories, isEmpty);
    final e = state.recentExpenses(1).single;
    expect(e.custom, isNull);
    expect(e.title, 'Vaping'); // kept as its note
  });

  test('money put into a jar is set aside until it\'s bought', () {
    final state = buildState();
    final start = state.snapshot.available;
    final burn = state.snapshot.burnRate;
    final jar = state.startJar(name: '  dior   wallet ', target: 500);
    expect(jar.name, 'Dior wallet');
    expect(state.snapshot.available, start); // nothing set aside yet

    final safe = state.snapshot.safeToSpendToday;
    state.putIntoJar(jar.id, 80);
    expect(state.jar(jar.id)!.saved, 80);
    // Out of today's money, all of it, not spread over the term.
    expect(state.snapshot.safeToSpendToday, closeTo(safe - 80, 1e-9));
    expect(state.recentJarDeposits().single.deposit.amount, 80);
    expect(state.snapshot.available, closeTo(start - 80, 1e-9));
    expect(state.snapshot.burnRate, burn); // saving isn't spending
    expect(state.grounding.savingFor.single.saved, 80);

    state.putIntoJar(jar.id, 1e5); // capped at what it still needs
    expect(state.jar(jar.id)!.saved, 500);
    expect(state.jar(jar.id)!.full, isTrue);
    expect(state.maxJarDeposit(state.jar(jar.id)!), 0);

    final before = state.snapshot.available;
    state.buyJar(jar.id);
    expect(state.jars, isEmpty);
    final bought = state.recentExpenses(1).single;
    expect(
      (bought.amount, bought.title, bought.category, bought.planned),
      (500.0, 'Dior wallet', ExpenseCategory.shopping, true),
    );
    // Paid with the 500 that was set aside: spending money doesn't move.
    expect(state.snapshot.available, closeTo(before, 1e-9));
  });

  test('taking money out the same day gives today all of it back', () {
    final state = buildState();
    final safe = state.snapshot.safeToSpendToday;
    final jar = state.startJar(name: 'Trip', target: 300);
    state.putIntoJar(jar.id, 80);
    state.takeOutOfJar(jar.id, 30);
    expect(state.jar(jar.id)!.saved, 50);
    expect(state.snapshot.safeToSpendToday, closeTo(safe - 50, 1e-9));
    expect(
      state.recentJarDeposits().map((d) => d.deposit.amount),
      unorderedEquals([-30, 80]),
    );

    state.takeOutOfJar(jar.id, 1e5); // never more than what's in it
    expect(state.jar(jar.id)!.saved, 0);
    expect(state.snapshot.safeToSpendToday, closeTo(safe, 1e-9));
    expect(state.jars, hasLength(1)); // still saving for it
  });

  test('stopping a jar gives its money back', () {
    final state = buildState();
    final start = state.snapshot.available;
    final jar = state.startJar(name: 'Trip', target: 300);
    state.putIntoJar(jar.id, 45);
    state.dropJar(jar.id);
    expect(state.jars, isEmpty);
    expect(state.snapshot.available, closeTo(start, 1e-9));
    expect(state.recentExpenses(1).single.title, isNot('Trip'));
  });

  testWidgets('save for something from the coach, then put money in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final state = buildState();
    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);

    await tester.tap(find.text('Coach'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Car \$5000');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await settle(tester, const Duration(seconds: 2));

    await tester.ensureVisible(find.text('Save for it'));
    await tester.tap(find.text('Save for it'));
    await settle(tester);
    expect(find.text('Save for something'), findsOneWidget);
    await tester.tap(find.text('Start saving'));
    await settle(tester);

    final jar = state.jars.single;
    expect((jar.name, jar.target, jar.saved), ('Car', 5000.0, 0.0));
    expect(find.text('Saving for it · See it'), findsOneWidget);

    await tester.tap(find.text('See it'));
    await settle(tester, const Duration(seconds: 1));
    expect(find.text('Saving for'), findsOneWidget);
    await tester.ensureVisible(find.text('Car'));
    await tester.tap(find.text('Car'));
    await settle(tester);
    final put = find.textContaining(RegExp(r'^Put \$\d+ in$'));
    expect(put, findsOneWidget);
    await tester.tap(put);
    await settle(tester);
    // Logged on Home's Recent list too.
    await tester.tap(find.text('Home'));
    await settle(tester, const Duration(seconds: 1));
    await tester.scrollUntilVisible(
      find.text('Put aside · Car'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Put aside · Car'), findsOneWidget);

    // Take it back out from the goal.
    await tester.tap(find.text('Put aside · Car'));
    await settle(tester);
    await tester.tap(find.text('Take out'));
    await settle(tester);
    final take = find.textContaining(RegExp(r'^Take \$\d+ out$'));
    expect(take, findsOneWidget);
    await tester.tap(take);
    await settle(tester);
    expect(state.jars.single.saved, 0);
    expect(find.text('Took out · Car'), findsOneWidget);
  });

  test('the savings goal is capped, and Home asks only once', () {
    final state = buildState();
    expect(state.offerSavingsGoal, isTrue);
    final daily = state.snapshot.dailyAllowance;
    state.setSavingsGoal(70);
    expect(state.offerSavingsGoal, isFalse);
    expect(
      state.snapshot.available,
      closeTo(state.snapshot.balance - 420 - 70, 1e-9),
    );
    expect(state.snapshot.dailyAllowance, lessThan(daily));

    state.setSavingsGoal(1e5); // more than there is
    expect(
      state.term.savingsGoal,
      closeTo(state.snapshot.maxSavingsGoal, 0.01),
    );
    state.setSavingsGoal(0);
    expect(state.term.savingsGoal, 0);
    expect(state.offerSavingsGoal, isFalse); // answered once already

    final other = buildState()..skipSavingsGoal();
    expect(other.offerSavingsGoal, isFalse);
  });

  testWidgets('a goal set from Home shows on the Savings tab', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = buildState();
    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);
    expect(find.text('Save something this term?'), findsNothing);
    expect(find.text('Save something this semester?'), findsOneWidget);
    await tester.tap(find.text('Set a goal'));
    await settle(tester);

    await tester.enterText(find.byType(TextField), '120');
    await settle(tester, const Duration(milliseconds: 300));
    expect(find.textContaining('Safe to spend each day'), findsOneWidget);
    await tester.tap(find.text('Save \$120 goal'));
    await settle(tester);
    expect(state.term.savingsGoal, 120);
    expect(find.text('Save something this semester?'), findsNothing);

    await tester.tap(find.text('Savings'));
    await settle(tester);
    // The demo spends faster than the budget, so the goal is at risk.
    expect(find.text('Heading for'), findsOneWidget);
    expect(find.textContaining('/day less to keep it all'), findsOneWidget);
    expect(find.textContaining('/day keeps it all'), findsOneWidget);
    expect(find.text('Saved so far'), findsOneWidget);
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

  testWidgets('a big cost and pay can be edited from Home', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final state = buildState();
    state.addIncome(
      name: 'Café shifts',
      amount: 100,
      frequency: IncomeFrequency.weekly,
      firstDate: now.subtract(const Duration(days: 7)),
    );

    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);

    // The phone bill: a one-off cost.
    final phone = find.descendant(
      of: find.byType(ListRow),
      matching: find.text('Phone bill'),
    );
    await centerOn(tester, phone);
    await tester.tap(phone);
    await settle(tester);
    await tester.tap(find.text('Edit'));
    await settle(tester);
    expect(find.text('Edit cost'), findsOneWidget);
    final costFields = find.descendant(
      of: find.byType(EditCostSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(costFields.at(1), '62.5');
    await settle(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Save \$62.50'));
    await settle(tester);
    expect(
      state.comingUp.firstWhere((c) => c.name == 'Phone bill').amount,
      62.5,
    );

    // The café pay has paid out, so a raise starts at the next payday.
    final pay = find.text('Café shifts');
    await centerOn(tester, pay);
    await tester.tap(pay);
    await settle(tester);
    await tester.tap(find.text('Edit'));
    await settle(tester);
    expect(find.text('Edit money coming in'), findsOneWidget);
    final payFields = find.descendant(
      of: find.byType(AddIncomeSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(payFields.at(1), '120');
    await settle(tester, const Duration(milliseconds: 300));
    // Sep 25 and today (Oct 2) were paid; the raise starts next Friday.
    expect(
      find.text('Paydays you\'ve had stay at \$100.00. \$120.00 starts Oct 9.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Save \$120.00'));
    await settle(tester);
    expect(state.incomes.map((i) => i.amount), [100, 120]);
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

  testWidgets('history lists past months and opens one read-only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final september = PastTerm(
      term: Term(
        name: 'September',
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 30),
        startingBalance: 500,
        period: BudgetPeriod.monthly,
      ),
      endedOn: DateTime(2026, 10, 1),
      expenses: [
        Expense(
          id: 'old-pizza',
          amount: 18,
          category: ExpenseCategory.lateNight,
          isNeed: false,
          date: DateTime(2026, 9, 12, 23),
          note: 'Pizza with Sam',
        ),
      ],
      incomes: const [],
    );
    final state = AppState(
      repository: _HistoryRepository(now, [september]),
      data: MockBudgetRepository.seed(now),
      user: const UserProfile(name: 'Alex'),
      clock: () => now,
    );

    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);
    await tester.tap(find.text('A'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('History'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('History'));
    await settle(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('History'));
    await settle(tester);

    expect(find.text('September'), findsOneWidget);
    expect(find.text('\$482 left'), findsOneWidget);
    expect(find.text('Monthly · Sep 1 – Sep 30, 2026'), findsOneWidget);
    expect(find.text('🍕 Late-night food \$18'), findsOneWidget);

    await tester.tap(find.text('September'));
    await settle(tester);
    expect(find.text('Pizza with Sam'), findsOneWidget);
    expect(find.text('Sep 12'), findsOneWidget);
    // Read-only: tapping an old expense doesn't offer edit or delete.
    await tester.tap(find.text('Pizza with Sam'));
    await settle(tester);
    expect(find.text('Delete expense'), findsNothing);
  });

  testWidgets('a recap pops up on Home when a month ends', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    PastTerm month(int m, String name, double start, List<Expense> spent) =>
        PastTerm(
          term: Term(
            name: name,
            start: DateTime(2026, m, 1),
            end: DateTime(2026, m + 1, 0),
            startingBalance: start,
            period: BudgetPeriod.monthly,
          ),
          endedOn: DateTime(2026, m + 1, 1, 9),
          expenses: spent,
          incomes: const [],
        );
    Expense spend(String id, double amount, ExpenseCategory c) => Expense(
      id: id,
      amount: amount,
      category: c,
      isNeed: c == ExpenseCategory.groceries,
      date: DateTime(2026, 9, 10),
    );
    final repo = MockBudgetRepository(now: now);
    final state = AppState(
      repository: repo,
      data: MockBudgetRepository.seed(now),
      user: const UserProfile(name: 'Alex'),
      clock: () => now,
    );

    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);
    final october = month(10, 'October', 500, [
      spend('a', 217, ExpenseCategory.delivery), // $7/day
      spend('b', 163, ExpenseCategory.groceries),
    ]);
    state.pendingRecap.value = (
      ended: october,
      before: month(9, 'September', 500, [
        spend('c', 300, ExpenseCategory.delivery), // $10/day
      ]),
    );
    await settle(tester, const Duration(seconds: 1));

    expect(find.text('That\'s a wrap on October'), findsOneWidget);
    expect(find.text('\$120.00'), findsOneWidget);
    expect(find.text('left over, carried into this month'), findsOneWidget);
    expect(find.text('43% · 57%'), findsOneWidget);
    expect(find.text('📦 Delivery \$217'), findsOneWidget);
    expect(
      find.text('30% less on 📦 Delivery than in September 🎉'),
      findsOneWidget,
    );
    expect(await repo.recapSeenUntil(), october.endedOn);

    await tester.tap(find.text('Nice'));
    await settle(tester);
    expect(find.text('That\'s a wrap on October'), findsNothing);
  });

  testWidgets('a recap shows what was saved and asks about next month', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final state = buildState()..setSavingsGoal(100);
    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);
    state.pendingRecap.value = (
      ended: PastTerm(
        term: Term(
          name: 'October',
          start: DateTime(2026, 10, 1),
          end: DateTime(2026, 10, 31),
          startingBalance: 500,
          period: BudgetPeriod.monthly,
          savingsGoal: 100,
        ),
        endedOn: DateTime(2026, 11, 1, 9),
        expenses: [
          Expense(
            id: 'a',
            amount: 360,
            category: ExpenseCategory.groceries,
            isNeed: true,
            date: DateTime(2026, 10, 10),
          ),
        ],
        incomes: const [],
        saved: 100,
      ),
      before: null,
    );
    await settle(tester);

    expect(find.text('\$40.00'), findsOneWidget); // left over, not saved
    expect(find.text('\$100 of \$100 🎉'), findsOneWidget);
    expect(find.text('Save \$100 again in Fall term?'), findsOneWidget);
    await tester.tap(find.text('Skip this month'));
    await settle(tester, const Duration(milliseconds: 300));
    expect(state.term.savingsGoal, 0);
    expect(find.text('Save something in Fall term?'), findsOneWidget);
  });

  testWidgets('history is empty until something ends', (tester) async {
    final state = buildState();
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await settle(tester);
    expect(
      find.text(
        'Nothing here yet. When a month or semester ends, it shows up here.',
      ),
      findsOneWidget,
    );
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

  testWidgets('calendar: tap a day, delete from it, later days follow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(750, 1334); // iPhone SE
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = buildState();
    // The latest day before today with something logged on it.
    final day = state.ledger.reversed
        .skip(1)
        .firstWhere((d) => state.expensesOn(d.day).isNotEmpty)
        .day;
    final first = state.expensesOn(day).first;
    final todayBefore = state.ledger.last.allowance;

    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);
    await centerOn(tester, find.text('Calendar'));
    await tester.tap(find.text('Calendar'));
    await settle(tester);
    expect(find.text('Today'), findsOneWidget);
    expect(tester.takeException(), isNull);

    if (day.month != state.today.month) {
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await settle(tester);
    }
    await tester.tap(find.bySemanticsLabel(RegExp('^\\w+ ${day.day}, spent')));
    await settle(tester);
    expect(find.text(first.title), findsWidgets);

    await tester.tap(find.text(first.title).first);
    await settle(tester);
    await tester.tap(find.text('Delete expense'));
    await settle(tester);
    expect(state.expensesOn(day).map((e) => e.id), isNot(contains(first.id)));
    expect(state.ledger.last.allowance, greaterThan(todayBefore));
    expect(tester.takeException(), isNull);
  });

  testWidgets('last week\'s recap shows on Home until it\'s dismissed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(750, 1334); // iPhone SE
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final state = buildState();
    await state.checkForWeekRecap();
    final recap = state.weekRecap!;
    expect(recap.words.fromModel, isFalse);

    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester);
    expect(find.text('Last week · ${recap.week.label}'), findsOneWidget);
    expect(find.text(recap.week.summary), findsOneWidget);
    expect(find.text('Apple Intelligence'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.bySemanticsLabel('Dismiss last week\'s recap'));
    await settle(tester);
    expect(find.textContaining('Last week ·'), findsNothing);
    // Dismissed for good: checking again doesn't bring it back.
    await state.checkForWeekRecap();
    expect(state.weekRecap, isNull);
  });

  test('the coach answers spending questions from the rules too', () async {
    final state = buildState();
    final reply = await state.coach.ask(
      'What did I spend last week?',
      state.grounding,
    );
    expect(reply.text, startsWith('You spent \$'));
    expect(reply.text, contains('last week'));
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

  group('Google sign-in', () {
    late _FakeAccounts accounts;
    setUp(() => accounts = _FakeAccounts());

    AppState stateWith({UserProfile? user}) => AppState(
      repository: MockBudgetRepository(now: now),
      data: MockBudgetRepository.seed(now),
      accounts: accounts,
      user: user,
      clock: () => now,
    );

    Future<void> boot(WidgetTester tester, AppState state) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(RunwayApp(state: state, intro: false));
      await settle(tester);
    }

    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.text('A')); // avatar initial
      await settle(tester);
    }

    testWidgets('only offered where Google sign-in is set up', (tester) async {
      await boot(
        tester,
        AppState(
          repository: MockBudgetRepository(now: now),
          data: MockBudgetRepository.seed(now),
          clock: () => now,
        ),
      );
      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('welcome: signs in and greets by Google first name', (
      tester,
    ) async {
      final state = stateWith();
      await boot(tester, state);

      await tester.tap(find.text('Continue with Google'));
      await settle(tester, const Duration(seconds: 3));

      expect(tester.takeException(), isNull);
      expect(state.account?.email, 'priya@gmail.com');
      expect(state.user?.name, 'Priya');
      expect(state.user?.email, 'priya@gmail.com');
      expect(find.text('Hey, Priya'), findsOneWidget);
    });

    testWidgets('welcome: backing out of Google stays put', (tester) async {
      accounts.result = null;
      final state = stateWith();
      await boot(tester, state);

      await tester.tap(find.text('Continue with Google'));
      await settle(tester);

      expect(state.user, isNull);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('welcome: a failed sign-in says why', (tester) async {
      accounts.error = const AccountException('No connection.');
      final state = stateWith();
      await boot(tester, state);

      await tester.tap(find.text('Continue with Google'));
      await settle(tester);

      expect(state.user, isNull);
      expect(find.text('No connection.'), findsOneWidget);
    });

    testWidgets('settings: signing in keeps the name you chose', (
      tester,
    ) async {
      final state = stateWith(user: const UserProfile(name: 'Alex'));
      await boot(tester, state);
      await openSettings(tester);

      await tester.tap(find.text('Continue with Google'));
      await settle(tester);

      expect(state.user?.name, 'Alex');
      expect(find.text('priya@gmail.com'), findsOneWidget);
    });

    testWidgets('settings: signing out keeps the budget', (tester) async {
      accounts.current = accounts.result;
      final state = stateWith(
        user: const UserProfile(name: 'Alex', email: 'priya@gmail.com'),
      );
      final spent = state.snapshot.totalSpent;
      await boot(tester, state);
      await openSettings(tester);

      await tester.tap(find.text('Sign out'));
      await settle(tester);
      await tester.tap(find.text('Sign out').last); // confirm in the sheet
      await settle(tester);

      expect(state.account, isNull);
      expect(state.user?.name, 'Alex');
      expect(state.user?.email, isEmpty);
      expect(state.snapshot.totalSpent, spent);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('settings: deleting the account', (tester) async {
      accounts.current = accounts.result;
      final state = stateWith(
        user: const UserProfile(name: 'Alex', email: 'priya@gmail.com'),
      );
      await boot(tester, state);
      await openSettings(tester);

      await centerOn(tester, find.text('Delete account'));
      await tester.tap(find.text('Delete account'));
      await settle(tester);
      await tester.tap(find.text('Delete account').last);
      await settle(tester);

      expect(accounts.deleted, isTrue);
      expect(state.account, isNull);
      expect(state.user?.name, 'Alex');
      expect(find.text('Your account was deleted.'), findsOneWidget);
    });

    test('a session found at launch becomes the profile', () {
      accounts.current = accounts.result;
      final fresh = stateWith()..adoptSignedInAccount();
      expect(fresh.user?.name, 'Priya');
      expect(fresh.user?.email, 'priya@gmail.com');

      final named = stateWith(user: const UserProfile(name: 'Alex'))
        ..adoptSignedInAccount();
      expect(named.user?.name, 'Alex');
      expect(named.user?.email, 'priya@gmail.com');
    });

    test('erasing everything also signs out', () async {
      accounts.current = accounts.result;
      final state = stateWith(user: const UserProfile(name: 'Alex'));
      await state.eraseEverything();
      expect(state.account, isNull);
      expect(state.user, isNull);
    });
  });

  group('real squad', () {
    late _FakeAccounts accounts;
    late _FakeSquad squads;
    setUp(() {
      accounts = _FakeAccounts();
      squads = _FakeSquad();
    });

    AppState stateWith({bool signedIn = true}) {
      if (signedIn) accounts.current = accounts.result;
      return AppState(
        repository: MockBudgetRepository(now: now),
        data: MockBudgetRepository.seed(now),
        accounts: accounts,
        squadService: squads,
        user: const UserProfile(name: 'Alex'),
        clock: () => now,
      );
    }

    Future<void> openSquad(WidgetTester tester, AppState state) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(RunwayApp(state: state, intro: false));
      await settle(tester);
      await tester.tap(find.text('Squad'));
      await settle(tester, const Duration(seconds: 2));
    }

    testWidgets('signed out: asks to sign in, then offers to start one', (
      tester,
    ) async {
      final state = stateWith(signedIn: false);
      await openSquad(tester, state);
      expect(find.text('Budget with your friends'), findsOneWidget);
      expect(find.text('Maya'), findsNothing); // no sample friends

      await tester.tap(find.text('Continue with Google'));
      await settle(tester, const Duration(seconds: 2));

      expect(find.text('Start a squad'), findsOneWidget);
      expect(squads.published?.name, 'Alex');
      expect(squads.published?.streak, state.streak);
    });

    testWidgets('starting a squad shows it with just you', (tester) async {
      final state = stateWith();
      await openSquad(tester, state);

      await tester.tap(find.text('Start squad'));
      await settle(tester);
      expect(find.text('Give your squad a name.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Apt 4B');
      await tester.tap(find.text('Start squad'));
      await settle(tester, const Duration(seconds: 2));

      expect(find.text('Apt 4B'), findsWidgets); // switcher + header
      expect(find.text('Just you so far'), findsOneWidget);
      expect(find.text('Invite friends'), findsOneWidget);
      expect(find.text('No-delivery week'), findsOneWidget);
    });

    testWidgets('joining with a code shows your friends\' streaks', (
      tester,
    ) async {
      final state = stateWith();
      await openSquad(tester, state);

      await tester.enterText(find.byType(TextField).last, 'wrong1');
      await tester.tap(find.text('Join'));
      await settle(tester);
      expect(find.textContaining('That code didn\'t work'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'k7m-2qx');
      await tester.tap(find.text('Join'));
      await settle(tester, const Duration(seconds: 2));

      expect(squads.joinedWith, 'k7m-2qx');
      expect(find.text('Roomies'), findsWidgets); // switcher + header
      expect(find.text('2 of 8 people'), findsOneWidget);
      // Challenge, leaderboard and the friends list.
      expect(find.text('Priya'), findsNWidgets(3));
      expect(find.text('Start a squad'), findsNothing);
    });

    testWidgets('leaving a squad goes back to start or join', (tester) async {
      squads.squad = _FakeSquad.roomies;
      final state = stateWith();
      await openSquad(tester, state);
      expect(find.text('Roomies'), findsWidgets); // switcher + header

      await tester.tap(find.bySemanticsLabel('Leave squad'));
      await settle(tester);
      await tester.tap(find.text('Leave squad').last);
      await settle(tester, const Duration(seconds: 2));

      expect(squads.left, isTrue);
      expect(find.text('Start a squad'), findsOneWidget);
    });

    testWidgets('a failed load says why', (tester) async {
      squads.error = const SquadException('Couldn\'t reach Squad.');
      final state = stateWith();
      await openSquad(tester, state);
      expect(find.text('Couldn\'t reach Squad.'), findsOneWidget);
    });

    testWidgets('split a bill: your squad, plus anyone by name', (
      tester,
    ) async {
      squads.squad = _FakeSquad.roomies;
      final state = stateWith();
      await openSquad(tester, state);
      // The sample IOUs from first launch aren't real people.
      expect(find.text('Pizza night'), findsNothing);

      await tester.ensureVisible(find.text('Split a bill'));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Split a bill'));
      await settle(tester);

      expect(find.text('🦊 Maya'), findsNothing);
      expect(find.text('🐼 Priya'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'Groceries');
      await tester.enterText(find.byType(TextField).at(1), '30');
      await tester.tap(find.text('🐼 Priya'));
      await tester.tap(find.text('Someone else'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, 'Sam');
      await tester.tap(find.bySemanticsLabel('Add'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Sam owes you'), findsOneWidget);

      await tester.ensureVisible(find.text('Split \$30.00'));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Split \$30.00'));
      await settle(tester, const Duration(seconds: 2));

      // Priya's part is synced; Sam isn't on Runway, so his stays here.
      final synced = squads.expenses.single;
      expect(synced.description, 'Groceries');
      expect(synced.paidBy, 'u1');
      expect(synced.shares, {'u1': 1000, 'u2': 1000});
      expect(
        state.splits.where((s) => s.note == 'Groceries').map((s) => s.person),
        ['Sam'],
      );
      // Your part counts once, as a synced split's expense.
      expect(
        state.allExpenses.where((e) => e.note == 'Groceries').single.amount,
        10,
      );
      expect(state.friendBalances, {'u2': 1000});
    });

    testWidgets('they paid, split by exact amounts: you owe them', (
      tester,
    ) async {
      squads.squad = _FakeSquad.roomies;
      final state = stateWith();
      await openSquad(tester, state);
      await tester.ensureVisible(find.text('Split a bill'));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Split a bill'));
      await settle(tester);

      await tester.enterText(find.byType(TextField).at(0), 'Concert');
      await tester.enterText(find.byType(TextField).at(1), '100');
      await tester.tap(find.text('🐼 Priya'));
      await settle(tester);
      await tester.ensureVisible(find.text('Priya').last);
      await tester.tap(find.text('Priya').last); // who paid
      await tester.ensureVisible(find.text('Exact amounts'));
      await tester.tap(find.text('Exact amounts'));
      await settle(tester);
      final fields = find.byType(TextField);
      final n = fields.evaluate().length;
      await tester.enterText(fields.at(n - 2), '60'); // you
      await tester.enterText(fields.at(n - 1), '30'); // Priya
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('\$10.00 still to assign.'), findsOneWidget);
      await tester.enterText(fields.at(n - 1), '40');
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('You owe Priya'), findsOneWidget);

      await tester.ensureVisible(find.text('Split \$100.00'));
      await tester.tap(find.text('Split \$100.00'));
      await settle(tester, const Duration(seconds: 2));

      expect(squads.expenses.single.paidBy, 'u2');
      expect(squads.expenses.single.kind, SplitKind.exact);
      expect(state.friendBalances, {'u2': -6000});
      expect(
        state.allExpenses.where((e) => e.note == 'Concert').single.amount,
        60,
      );
    });

    testWidgets('settle up with a friend', (tester) async {
      squads.squad = _FakeSquad.roomies;
      squads.expenses.add(
        SharedExpense(
          id: 'x9',
          paidBy: 'u1',
          description: 'Pizza',
          totalCents: 3000,
          shares: const {'u1': 1500, 'u2': 1500},
          createdAt: DateTime(2026, 10, 2, 9),
        ),
      );
      final state = stateWith();
      await openSquad(tester, state);
      expect(find.text('owes you \$15.00'), findsOneWidget);

      await tester.ensureVisible(find.text('owes you \$15.00'));
      await tester.tap(find.text('owes you \$15.00'));
      await settle(tester);
      expect(find.text('Priya owes you \$15.00'), findsOneWidget);
      await tester.tap(find.text('Settle up'));
      await settle(tester);
      await tester.tap(find.text('Record'));
      await settle(tester, const Duration(seconds: 2));

      expect(squads.settlements, [
        const SettlementItem(
          squadId: null,
          from: 'u2',
          to: 'u1',
          amountCents: 1500,
        ),
      ]);
      expect(state.friendBalances, isEmpty);
      expect(find.text('All settled up'), findsOneWidget);
    });

    testWidgets('you can remove a settle-up from the history', (tester) async {
      squads.squad = _FakeSquad.roomies;
      squads.expenses.add(
        SharedExpense(
          id: 'x9',
          paidBy: 'u1',
          description: 'Pizza',
          totalCents: 3000,
          shares: const {'u1': 1500, 'u2': 1500},
          createdAt: DateTime(2026, 10, 2, 9),
        ),
      );
      squads.settlements.add(
        const SettlementItem(
          squadId: null,
          from: 'u2',
          to: 'u1',
          amountCents: 1500,
        ),
      );
      final state = stateWith();
      await openSquad(tester, state);
      expect(state.friendBalances, isEmpty);

      unawaited(
        showFriendSheet(tester.element(find.text('Squad').first), 'u2'),
      );
      await settle(tester);
      await tester.longPress(find.textContaining('paid you'));
      await settle(tester);
      await tester.tap(find.text('Remove settle-up'));
      await settle(tester, const Duration(seconds: 2));

      expect(squads.removedSettlements, {'st0'});
      expect(state.friendBalances, {'u2': 1500});
      expect(find.text('Priya owes you \$15.00'), findsOneWidget);
    });

    testWidgets('you can delete a split a friend added', (tester) async {
      squads.squad = _FakeSquad.roomies;
      squads.expenses.add(
        SharedExpense(
          id: 'x9',
          createdBy: 'u2',
          paidBy: 'u2',
          description: 'Mystery bill',
          totalCents: 3000,
          shares: const {'u1': 1500, 'u2': 1500},
          createdAt: DateTime(2026, 10, 2, 9),
        ),
      );
      final state = stateWith();
      await openSquad(tester, state);
      expect(state.friendBalances, {'u2': -1500});

      unawaited(
        showFriendSheet(tester.element(find.text('Squad').first), 'u2'),
      );
      await settle(tester);
      await tester.longPress(find.text('Mystery bill').last);
      await settle(tester);
      await tester.tap(find.text('Delete split'));
      await settle(tester, const Duration(seconds: 2));

      expect(squads.expenses.single.deleted, isTrue);
      expect(state.friendBalances, isEmpty);
    });

    testWidgets('a friend\'s split shows up in your budget once', (
      tester,
    ) async {
      squads.squad = _FakeSquad.roomies;
      squads.expenses.add(
        SharedExpense(
          id: 'x7',
          paidBy: 'u2',
          description: 'Uber home',
          category: 'rideshare',
          totalCents: 2400,
          shares: const {'u1': 1200, 'u2': 1200},
          createdAt: DateTime(2026, 10, 2, 9),
        ),
      );
      final state = stateWith();
      await openSquad(tester, state);
      await state.refreshSquad();
      await tester.pump();

      final mine = state.allExpenses.where((e) => e.note == 'Uber home');
      expect(mine.single.amount, 12);
      expect(mine.single.category, ExpenseCategory.rideshare);
      expect(state.friendBalances, {'u2': -1200});
    });

    testWidgets('several squads: switch between them', (tester) async {
      squads.joined.addAll([_FakeSquad.roomies, _FakeSquad.trip]);
      final state = stateWith();
      await openSquad(tester, state);
      expect(state.squad?.name, 'Roomies');
      expect(find.text('Jordan'), findsWidgets); // a friend via the trip

      await tester.tap(find.text('Spring trip').first);
      await settle(tester);
      expect(state.squad?.name, 'Spring trip');
      expect(find.text('New squad'), findsOneWidget);
    });

    testWidgets('add a friend with their code', (tester) async {
      final state = stateWith();
      await openSquad(tester, state);
      await tester.ensureVisible(find.text('Add friend'));
      await tester.tap(find.text('Add friend'));
      await settle(tester);
      expect(find.text('FRND22'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'nope00');
      await tester.tap(find.text('Add friend').last);
      await settle(tester);
      expect(find.textContaining('didn\'t work'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'sam-123');
      await tester.tap(find.text('Add friend').last);
      await settle(tester, const Duration(seconds: 2));
      expect(squads.friendCodeUsed, 'sam-123');
      expect(state.friendPeople.map((p) => p.name), contains('Sam'));
    });

    test('signing out forgets the squad', () async {
      squads.squad = _FakeSquad.roomies;
      final state = stateWith();
      await state.refreshSquad();
      expect(state.squad?.name, 'Roomies');
      await state.signOutAccount();
      expect(state.squad, isNull);
    });
  });

  group('budget sync', () {
    late _FakeAccounts accounts;
    late FakeServer server;
    late MockBudgetRepository repo;
    const cipher = BudgetCipher(iterations: 1000);

    setUp(() {
      accounts = _FakeAccounts()..current = _FakeAccounts().result;
      server = FakeServer();
      repo = MockBudgetRepository(now: now);
    });

    AppState stateWith({bool fresh = false}) {
      final demo = MockBudgetRepository.seed(now);
      return AppState(
        repository: repo,
        data: fresh
            ? BudgetData(
                term: demo.term,
                expenses: demo.expenses,
                upcoming: demo.upcoming,
                friends: demo.friends,
                splits: demo.splits,
                challengeStart: demo.challengeStart,
                needsSetup: true,
              )
            : demo,
        accounts: accounts,
        budgetBackups: server,
        budgetCipher: cipher,
        user: const UserProfile(name: 'Alex', email: 'priya@gmail.com'),
        clock: () => now,
      );
    }

    Future<void> boot(WidgetTester tester, AppState state) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(RunwayApp(state: state, intro: false));
      await settle(tester);
    }

    /// Puts a synced copy on the server, as another device would.
    Future<void> syncFromAnotherDevice(String passphrase) async {
      final other = BudgetSyncController(
        store: server,
        local: MemorySyncStore(),
        exportBudget: () async => {'schema': 6, 'from': 'phone'},
        importBudget: (_) async {},
        userId: () => 'u1',
        cipher: cipher,
      );
      await other.turnOn(passphrase);
    }

    testWidgets('settings: turning sync on uploads an encrypted copy', (
      tester,
    ) async {
      repo.snapshot = {'schema': 6, 'note': 'Rent 900'};
      final state = stateWith();
      await boot(tester, state);
      await tester.tap(find.text('A'));
      await settle(tester);

      await centerOn(tester, find.text('Budget sync'));
      expect(find.textContaining('Off. Turn on'), findsOneWidget);
      await tester.tap(find.text('Budget sync'));
      await settle(tester);

      final fields = find.byType(TextField);
      await tester.enterText(
        fields.at(fields.evaluate().length - 2),
        'correct horse',
      );
      await tester.enterText(fields.last, 'different');
      await tester.tap(find.text('Turn on sync'));
      await settle(tester);
      expect(find.text('The passphrases don\'t match.'), findsOneWidget);

      await tester.enterText(fields.last, 'correct horse');
      await tester.tap(find.text('Turn on sync'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await settle(tester);

      expect(state.sync.status, SyncStatus.on);
      expect(server.budget!.ciphertext, isNot(contains('Rent')));
      expect(find.text('Budget sync is on.'), findsOneWidget);
    });

    testWidgets('a fresh device unlocks the synced budget before setup', (
      tester,
    ) async {
      await syncFromAnotherDevice('correct horse');
      final state = stateWith(fresh: true);
      await state.sync.check();
      expect(state.sync.status, SyncStatus.needsPassphrase);

      await boot(tester, state);
      expect(find.text('Welcome back 👋'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'wrong horse');
      await tester.tap(find.text('Unlock my budget'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await settle(tester);
      expect(find.textContaining('didn\'t open it'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'correct horse');
      await tester.tap(find.text('Unlock my budget'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await settle(tester);

      expect(repo.snapshot['from'], 'phone');
      expect(state.sync.status, SyncStatus.on);
    });

    testWidgets('a fresh device can start fresh instead', (tester) async {
      await syncFromAnotherDevice('correct horse');
      final state = stateWith(fresh: true);
      await state.sync.check();
      await boot(tester, state);

      await tester.tap(find.text('Start fresh on this device instead'));
      await settle(tester);
      expect(find.text('Set up your semester'), findsOneWidget);
    });

    test('signing out forgets the key on this device', () async {
      final state = stateWith();
      await state.sync.turnOn('correct horse');
      expect(state.sync.status, SyncStatus.on);
      await state.signOutAccount();
      await pumpEventQueue();
      expect(state.sync.status, SyncStatus.off);
      expect(server.row, isNotNull); // the copy stays for next time
    });
  });

  test('invite codes are cleaned up like the server does', () {
    expect(cleanInviteCode(' k7m-2qx '), 'K7M2QX');
    expect(validateSquadName('  '), isNotNull);
    expect(validateSquadName('Apt 4B'), isNull);
  });

  test('first names come from a full Google name', () {
    expect(firstNameOf('Priya Patel'), 'Priya');
    expect(firstNameOf('  Sam  '), 'Sam');
    expect(firstNameOf('x' * 40).length, 30);
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

  group('reminders', () {
    AppState withReminders(_FakeReminders r) => AppState(
      repository: MockBudgetRepository(now: now),
      data: MockBudgetRepository.seed(now),
      user: const UserProfile(name: 'Alex', email: 'alex@uni.edu'),
      clock: () => now,
      reminderScheduler: r,
    );
    Future<void> scheduled() => Future<void>.delayed(Duration.zero);

    test('turning one on asks first; a no leaves it off', () async {
      final r = _FakeReminders(allow: false);
      final state = withReminders(r);
      expect(
        await state.setReminders(const ReminderSettings(checkIn: true)),
        isFalse,
      );
      expect(r.asked, 1);
      expect(state.reminders.checkIn, isFalse);
    });

    test('the check-in skips today once something is logged', () async {
      final r = _FakeReminders();
      final state = withReminders(r);
      await state.setReminders(const ReminderSettings(checkIn: true));
      await scheduled();
      // The demo data has a coffee logged this morning.
      final tomorrow8pm = DateTime(now.year, now.month, now.day + 1, 20);
      expect(r.plan.first.at, tomorrow8pm);

      for (final e in state.allExpenses.where((e) => sameDay(e.date, now))) {
        state.deleteExpense(e.id);
      }
      state.refreshReminders();
      await scheduled();
      expect(r.plan.first.at, DateTime(now.year, now.month, now.day, 20));
    });

    test('tapping the check-in asks for Quick Add', () {
      final state = withReminders(_FakeReminders());
      state.reminderTapped(ReminderTap.quickAdd);
      expect(state.quickAddRequested.value, isTrue);
    });

    test('the first big cost offers bill reminders, once', () {
      final state = withReminders(_FakeReminders());
      UpcomingCost cost(String id) => UpcomingCost(
        id: id,
        emoji: '🎫',
        name: 'Concert',
        amount: 60,
        dueDate: now.add(const Duration(days: 10)),
      );
      state.addUpcomingCost(cost('a'));
      expect(state.offerBillReminders.value, isTrue);
      state.offerBillReminders.value = false;
      state.addUpcomingCost(cost('b'));
      expect(state.offerBillReminders.value, isFalse);
    });

    testWidgets('settings has a switch for each', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final r = _FakeReminders();
      final state = withReminders(r);
      await tester.pumpWidget(RunwayApp(state: state, intro: false));
      await settle(tester);
      await tester.ensureVisible(find.text('A'));
      await settle(tester);
      await tester.tap(find.text('A'));
      await settle(tester);
      await centerOn(tester, find.text('Evening check-in'));
      expect(find.text('Bills due tomorrow'), findsOneWidget);
      expect(find.text('Weekly recap'), findsOneWidget);
      final checkIn = find.descendant(
        of: find
            .ancestor(
              of: find.text('Evening check-in'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byType(Switch),
      );
      await tester.tap(checkIn);
      await settle(tester);
      expect(state.reminders.checkIn, isTrue);
      expect(r.asked, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no section where reminders aren\'t supported', (tester) async {
      await tester.pumpWidget(RunwayApp(state: buildState(), intro: false));
      await settle(tester);
      await tester.ensureVisible(find.text('A'));
      await settle(tester);
      await tester.tap(find.text('A'));
      await settle(tester);
      expect(find.text('Bills due tomorrow'), findsNothing);
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

/// Demo data plus a fixed history.
class _HistoryRepository extends MockBudgetRepository {
  _HistoryRepository(DateTime now, this._past) : super(now: now);
  final List<PastTerm> _past;

  @override
  Future<List<PastTerm>> history() async => _past;
}

/// Google sign-in without Google: returns [result] (null = backed out) or
/// throws [error].
class _FakeAccounts implements AccountService {
  Account? result = const Account(
    id: 'u1',
    email: 'priya@gmail.com',
    firstName: 'Priya',
  );
  AccountException? error;
  bool deleted = false;

  @override
  Account? current;

  @override
  bool get canUseGoogle => true;

  @override
  Future<Account?> signInWithGoogle() async {
    if (error case final e?) throw e;
    return current = result;
  }

  @override
  Future<void> signOut() async => current = null;

  @override
  Future<void> deleteAccount() async {
    deleted = true;
    current = null;
  }
}

/// Squads, friends and splits without a server; you are `u1`. [squad]
/// sets the one squad you're in; [error] makes the next load fail.
class _FakeSquad implements SquadService {
  final joined = <Squad>[];
  final direct = <String, Person>{};
  final expenses = <SharedExpense>[];
  final settlements = <SettlementItem>[];
  final removedSettlements = <String>{};
  SquadException? error;
  SquadStats? published;
  String? joinedWith;
  bool left = false;
  String? friendCodeUsed;

  set squad(Squad? s) {
    joined
      ..clear()
      ..addAll([?s]);
  }

  static const me = 'u1';

  static const roomies = Squad(
    id: 's1',
    name: 'Roomies',
    members: [
      SquadMember(
        userId: 'u1',
        name: 'Alex',
        emoji: '🦊',
        streak: 3,
        noDeliveryDays: [true],
        isMe: true,
      ),
      SquadMember(
        userId: 'u2',
        name: 'Priya',
        emoji: '🐼',
        streak: 9,
        noDeliveryDays: [true, false],
      ),
    ],
  );

  static const trip = Squad(
    id: 's3',
    name: 'Spring trip',
    members: [
      SquadMember(
        userId: 'u1',
        name: 'Alex',
        emoji: '🦊',
        streak: 3,
        noDeliveryDays: [true],
        isMe: true,
      ),
      SquadMember(
        userId: 'u3',
        name: 'Jordan',
        emoji: '🐸',
        streak: 1,
        noDeliveryDays: [false],
      ),
    ],
  );

  @override
  Future<SocialData?> sync(SquadStats stats) async {
    published = stats;
    if (error case final e?) throw e;
    final people = <String, Person>{};
    for (final sq in joined) {
      for (final m in sq.members) {
        if (m.isMe) continue;
        final had = people[m.userId];
        people[m.userId] = Person(
          id: m.userId,
          name: m.name,
          emoji: m.emoji,
          squadIds: {...?had?.squadIds, sq.id},
          direct: direct.containsKey(m.userId),
        );
      }
    }
    for (final f in direct.values) {
      people.putIfAbsent(
        f.id,
        () => Person(id: f.id, name: f.name, emoji: f.emoji, direct: true),
      );
    }
    var n = 0;
    return SocialData(
      me: me,
      squads: [...joined],
      people: people,
      expenses: [...expenses],
      settlements: [
        for (final i in settlements)
          if (!removedSettlements.contains('st${n++}'))
            Settlement(
              id: 'st${n - 1}',
              from: i.from,
              to: i.to,
              amountCents: i.amountCents,
              squadId: i.squadId,
              createdAt: DateTime(2026, 10, 2),
            ),
      ],
    );
  }

  @override
  Future<String> create(String name, SquadStats stats) async {
    published = stats;
    joined.add(
      Squad(
        id: 's2',
        name: name,
        members: [
          SquadMember(
            userId: me,
            name: stats.name,
            emoji: '🦊',
            streak: stats.streak,
            noDeliveryDays: stats.noDeliveryDays,
            isMe: true,
          ),
        ],
      ),
    );
    return 's2';
  }

  @override
  Future<String?> join(String code, SquadStats stats) async {
    if (cleanInviteCode(code) != 'K7M2QX') return null;
    joinedWith = code;
    squad = roomies;
    return roomies.id;
  }

  @override
  Future<String> inviteCode(String squadId) async => 'K7M2QX';

  @override
  Future<void> leave(String squadId) async {
    left = true;
    joined.removeWhere((s) => s.id == squadId);
  }

  @override
  Future<String> friendCode() async => 'FRND22';

  @override
  Future<bool> addFriend(String code, SquadStats stats) async {
    if (cleanInviteCode(code) != 'SAM123') return false;
    friendCodeUsed = code;
    direct['u4'] = const Person(id: 'u4', name: 'Sam', emoji: '🐙');
    return true;
  }

  @override
  Future<void> removeFriend(String personId) async => direct.remove(personId);

  @override
  Future<String> addSharedExpense({
    required String? squadId,
    required String description,
    required String category,
    required int totalCents,
    required String paidBy,
    required SplitKind kind,
    required Map<String, int> shares,
  }) async {
    final id = 'x${expenses.length + 1}';
    expenses.add(
      SharedExpense(
        id: id,
        squadId: squadId,
        createdBy: me,
        paidBy: paidBy,
        description: description,
        category: category,
        kind: kind,
        totalCents: totalCents,
        shares: shares,
        createdAt: DateTime(2026, 10, 2, 12),
      ),
    );
    return id;
  }

  @override
  Future<void> deleteSharedExpense(String id) async {
    final i = expenses.indexWhere((e) => e.id == id);
    final e = expenses[i];
    expenses[i] = SharedExpense(
      id: e.id,
      squadId: e.squadId,
      createdBy: e.createdBy,
      paidBy: e.paidBy,
      description: e.description,
      category: e.category,
      kind: e.kind,
      totalCents: e.totalCents,
      shares: e.shares,
      createdAt: e.createdAt,
      deleted: true,
    );
  }

  @override
  Future<void> recordSettlements(List<SettlementItem> items) async =>
      settlements.addAll(items);

  @override
  Future<void> deleteSettlement(String id) async => removedSettlements.add(id);

  @override
  Future<void> setSimplifyDebts(String squadId, bool on) async {}
}

class _FakeReminders implements ReminderScheduler {
  _FakeReminders({this.allow = true});
  final bool allow;
  int asked = 0;
  List<PlannedReminder> plan = const [];

  @override
  bool get supported => true;

  @override
  Future<bool> requestPermission() async {
    asked++;
    return allow;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async =>
      plan = reminders;
}
