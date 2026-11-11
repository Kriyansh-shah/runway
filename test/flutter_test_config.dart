import 'dart:async';

import 'package:runway/app/features.dart';

/// The tests were written with Squad in the app, so they run with it on.
/// launch_without_squad_test.dart turns it off to check the App Store 1.0
/// build, where Squad is held back for the next update.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Features.squad = true;
  await testMain();
}
