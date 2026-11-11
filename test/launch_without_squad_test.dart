// The App Store 1.0 build: Squad is held back for the next update, and Sign
// in with Apple sits next to Google.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/app_state.dart';
import 'package:runway/app/auth.dart';
import 'package:runway/app/features.dart';
import 'package:runway/app/repository.dart';
import 'package:runway/main.dart';
import 'package:runway/screens/squad_screen.dart';
import 'package:runway/widgets/apple_button.dart';

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

/// Apple and Google sign-in without either.
class _Accounts implements AccountService {
  Account? apple = const Account(
    id: 'a1',
    email: 'x7k2@privaterelay.appleid.com',
    firstName: 'Sam',
    provider: SignInProvider.apple,
  );
  AccountException? error;
  int appleSignIns = 0;
  bool deleted = false;

  @override
  Account? current;

  @override
  bool get canUseGoogle => true;

  @override
  bool get canUseApple => true;

  @override
  Future<Account?> signInWithGoogle() async => null;

  @override
  Future<Account?> signInWithApple() async {
    appleSignIns++;
    if (error case final e?) throw e;
    return current = apple;
  }

  @override
  Future<void> signOut() async => current = null;

  @override
  Future<void> deleteAccount() async {
    deleted = true;
    current = null;
  }
}

void main() {
  final now = DateTime(2026, 10, 2, 15);
  late _Accounts accounts;

  setUp(() {
    Features.squad = false;
    accounts = _Accounts();
  });
  tearDown(() => Features.squad = true);

  AppState stateWith({UserProfile? user = const UserProfile(name: 'Alex')}) =>
      AppState(
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

  group('without Squad', () {
    testWidgets('the tab bar has no Squad tab', (tester) async {
      await boot(tester, stateWith());

      for (final tab in ['Home', 'Savings', 'Coach']) {
        expect(find.text(tab), findsWidgets);
      }
      expect(find.bySemanticsLabel('Add expense'), findsOneWidget);
      expect(find.text('Squad'), findsNothing);
      expect(find.byType(SquadScreen), findsNothing);
    });

    testWidgets('nothing can open the Squad tab', (tester) async {
      final state = stateWith();
      await boot(tester, state);

      state.requestedTab.value = 3;
      await settle(tester);

      expect(find.byType(SquadScreen), findsNothing);
      expect(find.text('Safe to spend today'), findsOneWidget);
    });

    testWidgets('no screen mentions Squad, friends or splits', (tester) async {
      await boot(tester, stateWith());
      final words = RegExp(
        r'squad|split a bill|settle up|leaderboard|friend code|no-delivery',
        caseSensitive: false,
      );

      void check(String where) {
        final mentions = [
          for (final w in tester.widgetList<Text>(find.byType(Text)))
            if (words.hasMatch(w.data ?? w.textSpan?.toPlainText() ?? ''))
              w.data ?? w.textSpan!.toPlainText(),
        ];
        expect(mentions, isEmpty, reason: 'on $where');
      }

      check('Home');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await settle(tester);
      check('Home, scrolled');
      for (final tab in ['Savings', 'Coach']) {
        await tester.tap(find.text(tab).last);
        await settle(tester);
        check(tab);
      }
      await tester.tap(find.bySemanticsLabel('Add expense'));
      await settle(tester);
      check('Quick Add');
    });

    testWidgets('Settings has no Squad rows or wording', (tester) async {
      accounts.current = accounts.apple;
      await boot(
        tester,
        stateWith(
          user: const UserProfile(
            name: 'Alex',
            email: 'x7k2@privaterelay.appleid.com',
          ),
        ),
      );
      await tester.tap(find.text('A')); // avatar initial
      await settle(tester);

      expect(find.text('Blocked people'), findsNothing);
      expect(find.textContaining('Squad'), findsNothing);
      expect(find.text('Signed in with Apple'), findsOneWidget);
      expect(find.text('Budget sync'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
    });
  });

  group('iPad', () {
    for (final (name, size) in [
      ('portrait', const Size(2048, 2732)),
      ('landscape', const Size(2732, 2048)),
    ]) {
      testWidgets('every tab lays out on a 13" iPad, $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(RunwayApp(state: stateWith(), intro: false));
        await settle(tester);
        expect(tester.takeException(), isNull);
        for (final tab in ['Savings', 'Coach', 'Home']) {
          await tester.tap(find.text(tab).last);
          await settle(tester);
          expect(tester.takeException(), isNull, reason: tab);
        }
        await tester.tap(find.text('A')); // Settings
        await settle(tester);
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -6000));
        await settle(tester);
        expect(find.text('Privacy policy'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Settings');
        Navigator.of(tester.element(find.text('Privacy policy'))).pop();
        await settle(tester);
        await tester.tap(find.bySemanticsLabel('Add expense'));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'Quick Add');
      });
    }

    testWidgets('the welcome screen fits an iPad in landscape', (tester) async {
      tester.view.physicalSize = const Size(2732, 2048);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        RunwayApp(state: stateWith(user: null), intro: false),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Continue with Apple'), findsOneWidget);
    });
  });

  group('Sign in with Apple', () {
    testWidgets('welcome offers Apple above Google', (tester) async {
      await boot(tester, stateWith(user: null));

      final apple = tester.getTopLeft(find.text('Continue with Apple'));
      final google = tester.getTopLeft(find.text('Continue with Google'));
      expect(apple.dy, lessThan(google.dy));
      // Same size as the Google button, as Apple's guidelines ask.
      expect(
        tester.getSize(find.byType(AppleButton)).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('welcome: signs in and greets by the name Apple shares', (
      tester,
    ) async {
      final state = stateWith(user: null);
      await boot(tester, state);

      await tester.tap(find.text('Continue with Apple'));
      await settle(tester, const Duration(seconds: 3));

      expect(tester.takeException(), isNull);
      expect(accounts.appleSignIns, 1);
      expect(state.account?.provider, SignInProvider.apple);
      expect(state.user?.name, 'Sam');
      expect(find.text('Hey, Sam'), findsOneWidget);
    });

    testWidgets('welcome: backing out of Apple stays put', (tester) async {
      accounts.apple = null;
      final state = stateWith(user: null);
      await boot(tester, state);

      await tester.tap(find.text('Continue with Apple'));
      await settle(tester);

      expect(state.user, isNull);
      expect(find.text('Continue with Apple'), findsOneWidget);
    });

    testWidgets('welcome: when Apple can\'t sign in, it says why', (
      tester,
    ) async {
      accounts.error = const AccountException(
        'Sign in with Apple isn\'t available on this device right now.',
      );
      final state = stateWith(user: null);
      await boot(tester, state);

      await tester.tap(find.text('Continue with Apple'));
      await settle(tester);

      expect(state.user, isNull);
      expect(
        find.text(
          'Sign in with Apple isn\'t available on this device right now.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('settings: signing in with Apple keeps your name', (
      tester,
    ) async {
      final state = stateWith();
      await boot(tester, state);
      await tester.tap(find.text('A'));
      await settle(tester);

      await tester.tap(find.text('Continue with Apple'));
      await settle(tester);

      expect(state.user?.name, 'Alex');
      expect(find.text('Signed in with Apple'), findsOneWidget);
    });

    testWidgets('a name Apple didn\'t share falls back to Friend', (
      tester,
    ) async {
      accounts.apple = const Account(
        id: 'a2',
        email: '',
        provider: SignInProvider.apple,
      );
      final state = stateWith(user: null);
      await boot(tester, state);

      await tester.tap(find.text('Continue with Apple'));
      await settle(tester, const Duration(seconds: 3));

      expect(state.user?.name, 'Friend');
    });

    test('name-only builds offer neither', () {
      const none = NoAccounts();
      expect(none.canUseApple, isFalse);
      expect(none.canUseGoogle, isFalse);
    });
  });
}
