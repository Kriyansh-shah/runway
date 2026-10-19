/// Squad on Supabase. Row-level security means you only ever read squads
/// you're in and the profiles of people in them; joining goes through the
/// `join_squad` function so invite rules can't be skipped. See
/// supabase/migrations for the tables.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'squad.dart';

class SupabaseSquad implements SquadService {
  const SupabaseSquad();

  SupabaseClient get _client => Supabase.instance.client;

  /// Squad emojis, picked from your account ID so it stays the same.
  static const _emojis = ['🦊', '🐼', '🐸', '🐙', '🦄', '🐯', '🐨', '🐧'];

  String get _me {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const SquadException('Sign in to use Squad.');
    return id;
  }

  @override
  Future<Squad?> sync(SquadStats stats) => _guard(() async {
    final me = _me;
    await _publish(me, stats);
    final rows = await _client
        .from('squad_members')
        .select('squad_id, squads(name)')
        .eq('user_id', me)
        .order('joined_at')
        .limit(1);
    if (rows.isEmpty) return null;
    final row = rows.single;
    return _load(me, row['squad_id'] as String, _squadName(row));
  });

  @override
  Future<Squad> create(String name, SquadStats stats) => _guard(() async {
    final me = _me;
    await _publish(me, stats);
    final rows = await _client.rpc(
      'create_squad',
      params: {'squad_name': name.trim()},
    );
    final id = (rows as List).single['squad_id'] as String;
    return _load(me, id, name.trim());
  });

  @override
  Future<Squad?> join(String code, SquadStats stats) => _guard(() async {
    final me = _me;
    await _publish(me, stats);
    final id = await _client.rpc(
      'join_squad',
      params: {'invite_code': cleanInviteCode(code)},
    );
    if (id == null) return null;
    final squad = await _client
        .from('squads')
        .select('name')
        .eq('id', id as String)
        .single();
    return _load(me, id, squad['name'] as String);
  });

  @override
  Future<String> inviteCode(String squadId) => _guard(() async {
    final code = await _client.rpc(
      'squad_invite',
      params: {'target_squad': squadId},
    );
    return code as String;
  });

  @override
  Future<void> leave(String squadId) => _guard(() async {
    await _client
        .from('squad_members')
        .delete()
        .eq('squad_id', squadId)
        .eq('user_id', _me);
  });

  Future<void> _publish(String me, SquadStats stats) async {
    await _client.from('profiles').upsert({
      'id': me,
      'first_name': stats.name,
      'emoji': _emojis[me.codeUnits.fold(0, (a, b) => a + b) % _emojis.length],
      'streak': stats.streak,
      'no_delivery_days': stats.noDeliveryDays,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Squad> _load(String me, String id, String name) async {
    final rows = await _client
        .from('squad_members')
        .select(
          'user_id, profiles(first_name, emoji, streak, no_delivery_days)',
        )
        .eq('squad_id', id)
        .order('joined_at');
    return Squad(
      id: id,
      name: name,
      members: [
        for (final row in rows)
          if (row['profiles'] case final Map<String, dynamic> p)
            SquadMember(
              userId: row['user_id'] as String,
              name: p['first_name'] as String,
              emoji: p['emoji'] as String,
              streak: p['streak'] as int,
              noDeliveryDays: [
                for (final d in p['no_delivery_days'] as List) d as bool,
              ],
              isMe: row['user_id'] == me,
            ),
      ],
    );
  }

  static String _squadName(Map<String, dynamic> row) =>
      (row['squads'] as Map<String, dynamic>?)?['name'] as String? ?? 'Squad';

  /// Turns server and network errors into something to show.
  static Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on SquadException {
      rethrow;
    } on PostgrestException catch (e) {
      debugPrint('Squad request failed: ${e.code} ${e.message}');
      throw SquadException(switch (e.message) {
        'squad_full' => 'That squad is full ($maxSquadSize people max).',
        'too_many_squads' => 'You\'re already in 5 squads.',
        'too_many_attempts' => 'Too many wrong codes. Try again in an hour.',
        'too_many_invites' => 'Too many invites today. Try again tomorrow.',
        _ => 'Something went wrong with Squad. Try again.',
      });
    } on Exception catch (e) {
      debugPrint('Squad request failed: $e');
      throw const SquadException(
        'Couldn\'t reach Squad. Check your connection and try again.',
      );
    }
  }
}
