import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:device_preview/presets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'app/app_state.dart';
import 'app/repository.dart';
import 'app/theme.dart';
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

  final repository = MockBudgetRepository();
  final data = await repository.load();
  runApp(
    RunwayApp(
      state: AppState(repository: repository, data: data),
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
        home: const Shell(),
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
