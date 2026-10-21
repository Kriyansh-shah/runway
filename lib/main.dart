import 'dart:async';

// Apple Pay logging is switched off for now.
// import 'package:app_links/app_links.dart';
import 'package:device_preview/device_preview.dart';
import 'package:device_preview/presets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'app/app_state.dart';
import 'app/auth.dart';
import 'app/budget_sync.dart';
import 'app/database.dart';
import 'app/drift_repository.dart';
import 'app/squad.dart';
import 'app/supabase_accounts.dart';
import 'app/supabase_budget_backups.dart';
import 'app/supabase_squad.dart';
// import 'app/purchase_link.dart';
import 'app/theme.dart';
import 'screens/launch_intro.dart';
import 'screens/lock_gate.dart';
import 'screens/welcome_screen.dart';
import 'screens/setup_screen.dart';

Future<void> main() async {
  // On macOS debug builds, show the app inside an iPhone frame. Everywhere
  // else this behaves exactly like WidgetsFlutterBinding.
  DevicePreview.enable(
    enabled:
        kDebugMode && !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS,
  );
  final preview = DevicePreview.maybeController;
  if (preview != null) {
    unawaited(preview.applyPreset(DevicePresets.iPhone16ProMax));
  }

  // Everything is saved in runway.sqlite on this device. On first launch it
  // is filled with demo data once; after that it's your real data.
  final repository = DriftBudgetRepository(await RunwayDatabase.onDevice());
  final data = await repository.load();
  final user = await repository.currentUser();
  // Optional Google sign-in (iPhone, Android, web). If it can't start, the
  // app still opens, name-only.
  AccountService accounts = const NoAccounts();
  SquadService squad = const NoSquad();
  BudgetBackupStore backups = const NoBudgetBackups();
  LocalSyncStore? syncStore;
  if (SupabaseAccounts.supported) {
    try {
      // Bounded, so a stuck plugin or network can't leave a blank screen.
      accounts = await SupabaseAccounts.start().timeout(
        const Duration(seconds: 8),
      );
      squad = const SupabaseSquad();
      backups = const SupabaseBudgetBackups();
      syncStore = const SecureSyncStore();
    } on Object catch (error) {
      debugPrint('Sign-in unavailable: $error');
    }
  }
  final state = AppState(
    repository: repository,
    data: data,
    user: user,
    accounts: accounts,
    squadService: squad,
    budgetBackups: backups,
    syncStore: syncStore,
  );
  state.adoptSignedInAccount();
  // A fresh device that's signed in (the web after Google's redirect) asks
  // for the sync passphrase before setup, so it checks before showing
  // anything; otherwise sync catches up in the background.
  if (state.account != null && state.needsSetup) {
    await state.sync.check().timeout(
      const Duration(seconds: 6),
      onTimeout: () {},
    );
  } else {
    unawaited(state.sync.check());
  }
  // Loaded early so Split a bill can offer your squad from any tab.
  if (state.account != null) unawaited(state.refreshSquad());
  // A monthly budget moves on once its month is over, also when the app
  // comes back from the background in a new month.
  state.startNewMonthIfDue();
  // Offers a recap for a month that just ended (or one never shown).
  unawaited(state.checkForRecap());
  AppLifecycleListener(
    onResume: () {
      state.startNewMonthIfDue();
      unawaited(state.sync.check());
    },
    // Upload a pending change before the app is put away.
    onHide: () => unawaited(state.sync.flush()),
  );

  // Switched off for now. Apple Pay purchases arrive as runway://log links from a Shortcuts
  // automation, both when they launch the app and while it's open.
  // if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
  //   AppLinks().uriLinkStream.listen((uri) {
  //     final purchase = ApplePayPurchase.fromUri(uri);
  //     if (purchase != null) state.pendingPurchase.value = purchase;
  //   });
  // }

  runApp(RunwayApp(state: state));
}

class RunwayApp extends StatefulWidget {
  const RunwayApp({super.key, required this.state, this.intro = true});
  final AppState state;

  /// Play "Mochi's Takeoff" on launch. Tests turn it off.
  final bool intro;

  @override
  State<RunwayApp> createState() => _RunwayAppState();
}

class _RunwayAppState extends State<RunwayApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<SaveProblem>? _problems;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(RunwayApp old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _listen();
  }

  @override
  void dispose() {
    _problems?.cancel();
    super.dispose();
  }

  void _listen() {
    _problems?.cancel();
    _problems = widget.state.problems.listen(_showProblem);
  }

  /// Shown above whatever screen is open, clear of the floating nav bar.
  void _showProblem(SaveProblem problem) {
    final messenger = _messenger.currentState;
    if (messenger == null) return;
    final bottom = MediaQuery.paddingOf(messenger.context).bottom;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(problem.message),
          margin: EdgeInsets.fromLTRB(16, 0, 16, bottom + 96),
          duration: const Duration(seconds: 6),
          backgroundColor: const Color(0xFF3A1E24),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final intro = widget.intro;
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'runway',
        scaffoldMessengerKey: _messenger,
        // Above the navigator, so the lock and the app-switcher cover hide
        // every screen and sheet.
        builder: (context, child) => LockGate(child: child!),
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        scrollBehavior: const _BouncyScroll(),
        // Decided once at startup; after that, navigation is explicit so the
        // login → home reveal transition can run.
        home: switch ((state.user != null, intro)) {
          (false, _) => WelcomeScreen(playIntro: intro),
          (true, true) => const LaunchIntro(),
          (true, false) => landingFor(state),
        },
      ),
    );
  }
}

/// Bouncing physics everywhere, and mouse-drag scrolling for the macOS preview.
class _BouncyScroll extends MaterialScrollBehavior {
  const _BouncyScroll();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
