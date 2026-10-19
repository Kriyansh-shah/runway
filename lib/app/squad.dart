/// Squad: a small group of friends who see each other's first name, emoji,
/// logging streak and no-delivery-week dots. Never money. Behind an
/// interface so tests and the macOS preview work without a server.
library;

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
  const Squad({required this.id, required this.name, required this.members});
  final String id;
  final String name;

  /// Everyone in the squad, you included.
  final List<SquadMember> members;
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
  /// Shares your latest [stats], then loads your squad (null if you're in
  /// none). Needs a signed-in account.
  Future<Squad?> sync(SquadStats stats);

  /// Starts a squad called [name] with you in it.
  Future<Squad> create(String name, SquadStats stats);

  /// Joins the squad an invite [code] belongs to. Null when the code is
  /// wrong, expired or used up.
  Future<Squad?> join(String code, SquadStats stats);

  /// A code friends can join with; valid for at least a day.
  Future<String> inviteCode(String squadId);

  Future<void> leave(String squadId);
}

/// No server: Squad shows sample friends instead.
class NoSquad implements SquadService {
  const NoSquad();

  static const _offline = SquadException('Squad isn\'t available here.');

  @override
  Future<Squad?> sync(SquadStats stats) async => null;

  @override
  Future<Squad> create(String name, SquadStats stats) => throw _offline;

  @override
  Future<Squad?> join(String code, SquadStats stats) => throw _offline;

  @override
  Future<String> inviteCode(String squadId) => throw _offline;

  @override
  Future<void> leave(String squadId) async {}
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
