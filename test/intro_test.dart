import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/app_state.dart';
import 'package:runway/app/auth.dart';
import 'package:runway/app/repository.dart';
import 'package:runway/main.dart';
import 'package:runway/widgets/mochi_takeoff.dart';

void main() {
  final now = DateTime(2026, 10, 2, 15);

  AppState state({UserProfile? user}) => AppState(
    repository: MockBudgetRepository(now: now),
    data: MockBudgetRepository.seed(now),
    user: user,
    clock: () => now,
  );

  Future<void> boot(WidgetTester tester, AppState s) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RunwayApp(state: s));
  }

  /// Frame-by-frame so tickers advance like on a phone.
  Future<void> play(WidgetTester tester, Duration d) async {
    const frame = Duration(milliseconds: 16);
    for (var t = Duration.zero; t < d; t += frame) {
      await tester.pump(frame);
    }
  }

  group('scene maths', () {
    const size = Size(430, 932);
    const logo = Offset(215, 180);
    late TakeoffScene scene;
    setUp(() {
      scene = TakeoffScene(
        size: size,
        logoBaseline: logo,
        letters: LogoLetters.measure(),
      );
    });

    test('Mochi lands on top of each letter as it pops up', () {
      for (final (i, t) in [0.95, 1.20, 1.45, 1.70, 1.95, 2.20].indexed) {
        final m = scene.mochi(t)!;
        expect(m.y, closeTo(scene.letterTop(i, t), 0.5), reason: 'letter $i');
        expect(scene.letterScale(i, t).sy, greaterThan(0.6));
      }
    });

    test('the y is flattened during the beat, then springs back', () {
      expect(scene.letterScale(5, 2.45).sy, lessThan(0.6));
      expect(scene.letterScale(5, 3.4).sy, closeTo(1, 0.05));
    });

    test('Mochi is off-screen before entering and while flying', () {
      expect(scene.mochi(0.3), isNull);
      expect(scene.mochi(3.6), isNull);
    });

    test('the word ends exactly where the logo sits', () {
      final w = scene.word(kTakeoffEnd);
      expect(w.origin, logo);
      expect(w.scale, logoScale);
    });

    test(
      'final perch matches the static LogoMark, so the handoff is seamless',
      () {
        final letters = scene.letters;
        final expected = Offset(
          logo.dx + letters.letters[5].cx * logoScale,
          logo.dy - letters.xHeight * logoScale,
        );
        expect((scene.perchAt(kTakeoffEnd) - expected).distance, lessThan(0.5));
      },
    );
  });

  testWidgets('first launch: intro plays, then the login card is usable', (
    tester,
  ) async {
    final s = state();
    await boot(tester, s);
    expect(find.byType(MochiTakeoff), findsOneWidget);
    expect(find.byType(LogoMark), findsNothing);

    await play(tester, const Duration(milliseconds: 4600));
    expect(tester.takeException(), isNull);
    expect(find.byType(MochiTakeoff), findsNothing);
    expect(find.byType(LogoMark), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'maya@uni.edu');
    await tester.enterText(find.byType(TextField).at(1), 'hunter22');
    await tester.tap(find.text('Sign in').last);
    await play(tester, const Duration(seconds: 3));
    expect(find.text('Hey, Maya'), findsOneWidget);
  });

  testWidgets('tapping skips to the ending', (tester) async {
    await boot(tester, state());
    await play(tester, const Duration(milliseconds: 500));
    await tester.tap(find.byType(MochiTakeoff));
    await play(tester, const Duration(milliseconds: 900));
    expect(find.byType(MochiTakeoff), findsNothing);
    expect(find.byType(LogoMark), findsOneWidget);
  });

  testWidgets('signed in: intro reveals straight into Home', (tester) async {
    await boot(
      tester,
      state(
        user: const UserProfile(name: 'Alex', email: 'alex@uni.edu'),
      ),
    );
    await play(tester, const Duration(milliseconds: 5600));
    expect(tester.takeException(), isNull);
    expect(find.text('Hey, Alex'), findsOneWidget);
    expect(find.byType(MochiTakeoff), findsNothing);
  });

  testWidgets('Reduce Motion skips the intro', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await boot(tester, state());
    await tester.pump();
    expect(find.byType(MochiTakeoff), findsNothing);
    expect(find.byType(LogoMark), findsOneWidget);
  });
}
