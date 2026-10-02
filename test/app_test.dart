import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/app_state.dart';
import 'package:runway/app/models.dart';
import 'package:runway/app/repository.dart';
import 'package:runway/main.dart';
import 'package:runway/widgets/expense_inputs.dart';

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

void main() {
  final now = DateTime(2026, 10, 2, 15);

  AppState buildState() => AppState(
    repository: MockBudgetRepository(now: now),
    data: MockBudgetRepository.seed(now),
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

    await tester.pumpWidget(RunwayApp(state: buildState()));
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

  testWidgets('coach chip produces a verdict after typing', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RunwayApp(state: buildState()));
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
      clock: () => now,
    );
    final streak = state.streak;

    await tester.pumpWidget(RunwayApp(state: state));
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

    await tester.pumpWidget(RunwayApp(state: buildState()));
    await settle(tester);
    for (final tab in ['Coach', 'Squad', 'Home']) {
      await tester.tap(find.text(tab).last);
      await settle(tester);
    }
    await tester.tap(find.bySemanticsLabel('Add expense'));
    await settle(tester);
    expect(find.text('Quick add'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching tabs fully hides the previous tab', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RunwayApp(state: buildState()));
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
    await tester.pumpWidget(RunwayApp(state: state));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Add expense'));
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'Uber to airport');
    await tester.tap(find.text('2'));
    await tester.tap(find.text('7'));
    await settle(tester, const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text('🚕 Uber / ride'),
      120,
      scrollable: find.descendant(
        of: find.byType(CategoryPicker),
        matching: find.byType(Scrollable),
      ),
    );
    await settle(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('🚕 Uber / ride'));
    await settle(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Log \$27.00'));
    await settle(tester);

    final e = state.recentExpenses(1).single;
    expect(e.title, 'Uber to airport');
    expect(e.category, ExpenseCategory.rideshare);
    expect(e.amount, 27);
  });

  testWidgets('squad split-a-bill sheet creates IOUs', (tester) async {
    tester.view.physicalSize = const Size(750, 1334); // small phone
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final state = buildState();
    await tester.pumpWidget(RunwayApp(state: state));
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
}
