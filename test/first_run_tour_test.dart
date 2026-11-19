// The first-run tour on Home: a handwritten hello, then each part lit up in
// turn, moved on by tapping the lit part. Runs as the App Store 1.0 build
// (Friends tab, no squads).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/app_state.dart';
import 'package:runway/app/auth.dart';
import 'package:runway/app/features.dart';
import 'package:runway/app/models.dart';
import 'package:runway/app/repository.dart';
import 'package:runway/main.dart';
import 'package:runway/screens/first_run_tour.dart';
import 'package:runway/screens/settings_screen.dart';
import 'package:runway/widgets/pressable.dart';

/// The app has endless ambient animations, so pumpAndSettle never returns.
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

  setUp(() {
    Features.squad = false;
    Features.friends = true;
  });
  tearDown(() => Features.squad = true);

  Future<MockBudgetRepository> launch(
    WidgetTester tester, {
    TourProgress tour = TourProgress.notSeen,
  }) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // A fresh app, not an update of the last one.
    await tester.pumpWidget(const SizedBox());
    final repo = MockBudgetRepository(now: now, tour: tour);
    final state = AppState(
      repository: repo,
      data: MockBudgetRepository.seed(now),
      user: const UserProfile(name: 'Maya Lopez', email: 'maya@uni.edu'),
      clock: () => now,
    );
    await tester.pumpWidget(RunwayApp(state: state, intro: false));
    await settle(tester, const Duration(seconds: 2));
    return repo;
  }

  testWidgets('walks through every stop by tapping the lit part', (
    tester,
  ) async {
    final repo = await launch(tester);
    expect(find.text('hey Maya!\nwant a quick tour?'), findsOneWidget);

    await tester.tap(find.text('Show me'));
    await settle(tester);
    expect(find.text('Your number for today'), findsOneWidget);
    expect(find.text('1 of 6'), findsOneWidget);

    // Taps off the lit part don't move on or reach the screen below.
    await tester.tapAt(const Offset(30, 400));
    await settle(tester);
    expect(find.text('1 of 6'), findsOneWidget);

    for (final (name, title) in [
      ('the ring', 'Will your money last?'),
      ('Runway', 'Log spending in two taps'),
      ('+', 'Put money aside'),
      ('Savings', 'Ask about your money'),
      ('Coach', 'Split bills with friends'),
    ]) {
      await tester.tap(find.bySemanticsLabel('Tap $name to continue').first);
      await settle(tester);
      expect(find.text(title), findsOneWidget, reason: 'after $name');
    }
    await tester.tap(find.bySemanticsLabel('Tap Friends to continue').first);
    await settle(tester);
    expect(find.text('that’s it!'), findsOneWidget);

    await tester.tap(find.text('Start using Runway'));
    await settle(tester);
    expect(find.byType(FirstRunTour), findsNothing);
    expect(await repo.tourProgress(), TourProgress.seen);
    // Quick Add didn't open from the + tap during the tour.
    expect(find.text('Safe to spend today'), findsOneWidget);
  });

  testWidgets('"Maybe later" asks once more, then "No thanks" ends it', (
    tester,
  ) async {
    final repo = await launch(tester);
    await tester.tap(find.text('Maybe later'));
    await settle(tester);
    expect(find.byType(FirstRunTour), findsNothing);
    expect(await repo.tourProgress(), TourProgress.later);

    final again = await launch(tester, tour: TourProgress.later);
    expect(find.text('No thanks'), findsOneWidget);
    await tester.tap(find.text('No thanks'));
    await settle(tester);
    expect(await again.tourProgress(), TourProgress.seen);
  });

  testWidgets('stays away once seen, and Settings plays it again', (
    tester,
  ) async {
    await launch(tester, tour: TourProgress.seen);
    expect(find.byType(FirstRunTour), findsNothing);

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Pressable && w.semanticLabel == 'Settings',
      ),
    );
    await settle(tester);
    final row = find.text('Show the tour again');
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
    await settle(tester);
    await tester.tap(row);
    await settle(tester);
    expect(find.text('hey Maya!\nwant a quick tour?'), findsOneWidget);
    expect(find.text('No thanks'), findsOneWidget);
  });
}
