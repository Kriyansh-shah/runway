/// Features that are built but not shipped yet, and the switches that
/// hold them back.
///
/// Squads (shared squads with invite codes, the streak leaderboard, the
/// no-delivery challenge and Mochi's card on that tab) are held back from
/// the first App Store release; see docs/next-update-squad.md. Turn them on
/// in a build with `--dart-define=SQUAD=true`.
///
/// Friends (add friends with a code, split bills, settle up) ships in 1.0
/// as the Friends tab. `--dart-define=FRIENDS=false` hides it. Tests flip
/// the fields directly.
abstract final class Features {
  static bool squad = const bool.fromEnvironment('SQUAD');
  static bool friends = const bool.fromEnvironment(
    'FRIENDS',
    defaultValue: true,
  );

  /// The fourth tab exists: Squad, or Friends when squads are off.
  static bool get socialTab => squad || friends;
}
