/// Features that are built but not shipped yet.
///
/// Squad (friends, shared squads, bill splits, the streak leaderboard and
/// Mochi's pet card) is held back from the first App Store release and
/// comes in the next update; see docs/next-update-squad.md. Turn it on in a
/// build with `--dart-define=SQUAD=true`. Tests flip the field directly.
abstract final class Features {
  static bool squad = const bool.fromEnvironment('SQUAD');
}
