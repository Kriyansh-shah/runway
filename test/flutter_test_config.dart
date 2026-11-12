import 'dart:async';

import 'package:runway/app/features.dart';

/// The tests were written with squads in the app, so they run with them on.
/// launch_without_squad_test.dart and the "Friends tab" tests turn them off
/// to check the App Store 1.0 build: Friends without squads.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Features.squad = true;
  await testMain();
}
