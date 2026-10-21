/// Squads and friends. A squad is a small group who see each other's first
/// name, emoji, logging streak and no-delivery-week dots. Friends are
/// everyone you share a squad with, plus people added with a friend code;
/// you can split bills with any of them (only the people in a split see
/// its amounts). Behind an interface so tests and the macOS preview work
/// without a server.
library;

import 'split_math.dart';

class SquadMember {
  const SquadMember({
    required this.userId,
    required this.name,
    required this.emoji,
    required this.streak,
    required this.noDeliveryDays,
    this.isMe = false,
  });

  final String userId;
  final String name;
  final String emoji;
  final int streak;

  /// One entry per elapsed challenge day: true = stayed delivery-free.
  final List<bool> noDeliveryDays;
  final bool isMe;
}

class Squad {
  const Squad({
    required this.id,
    required this.name,
    required this.members,
    this.simplifyDebts = true,
  });
  final String id;
  final String name;

  /// Everyone in the squad, you included.
  final List<SquadMember> members;

  /// Splits in this squad are settled with the fewest payments.
  final bool simplifyDebts;
}

/// Someone you can split with: a squadmate or a friend you added.
class Person {
  const Person({
    required this.id,
    required this.name,
    required this.emoji,
    this.squadIds = const {},
    this.direct = false,
  });
  final String id;
  final String name;
  final String emoji;

  /// Squads you share with them.
  final Set<String> squadIds;

  /// Added one-to-one with a friend code (can be removed as a friend).
  final bool direct;
}

/// Everything social, loaded together: your squads, the people you know
/// and the splits and settle-ups you're part of.
class SocialData {
  const SocialData({
    required this.me,
    this.squads = const [],
    this.people = const {},
    this.expenses = const [],
    this.settlements = const [],
  });

  /// Your account ID.
  final String me;
  final List<Squad> squads;

  /// Friends and anyone you've split with, by account ID (not you).
  final Map<String, Person> people;
  final List<SharedExpense> expenses;
  final List<Settlement> settlements;

  /// People who are friends now (not just old split partners).
  Iterable<Person> get friends =>
      people.values.where((p) => p.direct || p.squadIds.isNotEmpty);

  SocialData copyWith({List<Squad>? squads}) => SocialData(
    me: me,
    squads: squads ?? this.squads,
    people: people,
    expenses: expenses,
    settlements: settlements,
  );
}

/// What you share with your squad. Nothing about money.
class SquadStats {
  const SquadStats({
    required this.name,
    required this.streak,
    required this.noDeliveryDays,
  });
  final String name;
  final int streak;
  final List<bool> noDeliveryDays;
}

/// Why a squad action didn't work, in words for the person.
class SquadException implements Exception {
  const SquadException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The most people in one squad (the server enforces it too).
const maxSquadSize = 8;

abstract interface class SquadService {
  /// Shares your latest [stats], then loads your squads, friends, splits
  /// and settle-ups. Needs a signed-in account.
  Future<SocialData?> sync(SquadStats stats);

  /// Starts a squad called [name] with you in it; returns its ID.
  Future<String> create(String name, SquadStats stats);

  /// Joins the squad an invite [code] belongs to; returns its ID, or null
  /// when the code is wrong, expired or used up.
  Future<String?> join(String code, SquadStats stats);

  /// A code friends can join a squad with; valid for at least a day.
  Future<String> inviteCode(String squadId);

  Future<void> leave(String squadId);

  /// Your friend code, for adding you one-to-one.
  Future<String> friendCode();

  /// Adds whoever's friend [code] this is. False for a wrong code.
  Future<bool> addFriend(String code, SquadStats stats);

  Future<void> removeFriend(String personId);

  /// Records a split; returns its ID. [shares] includes the payer.
  Future<String> addSharedExpense({
    required String? squadId,
    required String description,
    required String category,
    required int totalCents,
    required String paidBy,
    required SplitKind kind,
    required Map<String, int> shares,
  });

  Future<void> deleteSharedExpense(String id);

  Future<void> recordSettlements(List<SettlementItem> items);

  Future<void> setSimplifyDebts(String squadId, bool on);
}

/// No server: Squad shows sample friends instead.
class NoSquad implements SquadService {
  const NoSquad();

  static const _offline = SquadException('Squad isn\'t available here.');

  @override
  Future<SocialData?> sync(SquadStats stats) async => null;

  @override
  Future<String> create(String name, SquadStats stats) => throw _offline;

  @override
  Future<String?> join(String code, SquadStats stats) => throw _offline;

  @override
  Future<String> inviteCode(String squadId) => throw _offline;

  @override
  Future<void> leave(String squadId) async {}

  @override
  Future<String> friendCode() => throw _offline;

  @override
  Future<bool> addFriend(String code, SquadStats stats) => throw _offline;

  @override
  Future<void> removeFriend(String personId) => throw _offline;

  @override
  Future<String> addSharedExpense({
    required String? squadId,
    required String description,
    required String category,
    required int totalCents,
    required String paidBy,
    required SplitKind kind,
    required Map<String, int> shares,
  }) => throw _offline;

  @override
  Future<void> deleteSharedExpense(String id) => throw _offline;

  @override
  Future<void> recordSettlements(List<SettlementItem> items) => throw _offline;

  @override
  Future<void> setSimplifyDebts(String squadId, bool on) => throw _offline;
}

/// Error message for a squad name, or null when it's fine.
String? validateSquadName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Give your squad a name.';
  if (trimmed.length > 40) return 'Keep it under 40 characters.';
  return null;
}

/// "k7m-2qx " → "K7M2QX": what people type or paste, as the server stores it.
String cleanInviteCode(String code) =>
    code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
