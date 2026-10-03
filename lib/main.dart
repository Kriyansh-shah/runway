import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:device_preview/presets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'app/app_state.dart';
import 'app/database.dart';
import 'app/drift_repository.dart';
import 'app/theme.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';

Future<void> main() async {
  // On macOS debug builds, show the app inside an iPhone frame. Everywhere
  // else this behaves exactly like WidgetsFlutterBinding.
  DevicePreview.enable(
    enabled: kDebugMode && defaultTargetPlatform == TargetPlatform.macOS,
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
  runApp(
    RunwayApp(
      state: AppState(repository: repository, data: data, user: user),
    ),
  );
}

class RunwayApp extends StatelessWidget {
  const RunwayApp({super.key, required this.state});
  final AppState state;

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
        home: state.user == null ? const LoginScreen() : const Shell(),
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
