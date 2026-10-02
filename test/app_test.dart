import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/app_state.dart';
import 'package:runway/app/models.dart';
import 'package:runway/app/repository.dart';
import 'package:runway/main.dart';

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

    await tester.tap(find.textContaining('Groceries', findRichText: true));
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
}
