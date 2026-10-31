// Every main screen on a small phone with large text, at the extremes: the
// biggest amounts the inputs allow, and a budget spent far past zero. A
// layout overflow fails the test, so these catch "$999,999" not fitting.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/app_state.dart';
import 'package:runway/app/auth.dart';
import 'package:runway/app/models.dart';
import 'package:runway/app/repository.dart';
import 'package:runway/main.dart';

final _now = DateTime(2026, 10, 2, 15);

Future<void> _settle(WidgetTester tester, [int ms = 1500]) async {
  for (var t = 0; t < ms; t += 16) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

AppState _state({
  required double balance,
  double goal = 0,
  List<Expense> expenses = const [],
  List<UpcomingCost> upcoming = const [],
}) {
  final demo = MockBudgetRepository.seed(_now);
  return AppState(
    repository: MockBudgetRepository(now: _now),
    data: BudgetData(
      term: Term(
        name: 'A very long semester name here',
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 12, 11),
        startingBalance: balance,
        savingsGoal: goal,
      ),
      expenses: expenses,
      upcoming: upcoming,
      friends: demo.friends,
      splits: demo.splits,
      challengeStart: demo.challengeStart,
      savingsAsked: true,
    ),
    user: const UserProfile(name: 'Maximiliana', email: 'max@uni.edu'),
    clock: () => _now,
  );
}

Expense _spent(double amount, DateTime date, {String? note}) => Expense(
  id: 'e$amount${date.day}',
  amount: amount,
  category: ExpenseCategory.shopping,
  isNeed: false,
  date: date,
  note: note,
);

/// Opens each tab on an iPhone SE-sized screen with 1.3× text.
Future<void> _visitEveryTab(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(750, 1334);
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(RunwayApp(state: state, intro: false));
  await _settle(tester);
  expect(find.text('Safe to spend today'), findsOneWidget);
  // Down the whole of Home, past the stats, Coming up and Recent.
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
  await _settle(tester, 600);

  for (final tab in ['Savings', 'Coach', 'Squad', 'Home']) {
    await tester.tap(find.text(tab).last);
    await _settle(tester);
  }
}

void main() {
  testWidgets('the biggest amounts fit on every screen', (tester) async {
    final state = _state(
      balance: 999999.99,
      goal: 500000,
      expenses: [
        _spent(999999.99 / 4, DateTime(2026, 9, 2), note: 'x' * 40),
        _spent(0.01, _now),
      ],
      upcoming: [
        UpcomingCost(
          id: 'big',
          emoji: '🏠',
          name: 'A cost with the longest name allowed',
          amount: 249999.99,
          dueDate: DateTime(2026, 11, 1),
        ),
      ],
    );
    await _visitEveryTab(tester, state);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a budget spent far past zero still lays out', (tester) async {
    final state = _state(balance: 10, expenses: [_spent(999999.99, _now)]);
    expect(state.snapshot.available, lessThan(-999000));
    await _visitEveryTab(tester, state);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing at all: \$0 and no spending', (tester) async {
    await _visitEveryTab(tester, _state(balance: 0));
    expect(tester.takeException(), isNull);
  });
}
