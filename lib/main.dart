import 'dart:async';

// Apple Pay logging is switched off for now.
// import 'package:app_links/app_links.dart';
import 'package:device_preview/device_preview.dart';
import 'package:device_preview/presets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'app/app_state.dart';
import 'app/database.dart';
import 'app/drift_repository.dart';
// import 'app/purchase_link.dart';
import 'app/theme.dart';
import 'screens/launch_intro.dart';
import 'screens/login_screen.dart';
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
  final repository = DriftBudgetRepository(RunwayDatabase.onDevice());
  final data = await repository.load();
  final user = await repository.currentUser();
  final state = AppState(repository: repository, data: data, user: user);

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

class RunwayApp extends StatelessWidget {
  const RunwayApp({super.key, required this.state, this.intro = true});
  final AppState state;

  /// Play "Mochi's Takeoff" on launch. Tests turn it off.
  final bool intro;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Runway',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        scrollBehavior: const _BouncyScroll(),
        // Decided once at startup; after that, navigation is explicit so the
        // login → home reveal transition can run.
        home: switch ((state.user != null, intro)) {
          (false, _) => LoginScreen(playIntro: intro),
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
