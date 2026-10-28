/// Squads, friends and splits on Supabase. Row-level security means you
/// only ever read squads you're in, people you know, and splits and
/// settle-ups you're part of; every write goes through a function
/// (`join_squad`, `add_friend`, `add_shared_expense`, …) so the rules can't
/// be skipped. See supabase/migrations for the tables.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'split_math.dart';
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
  Future<SocialData?> sync(SquadStats stats) => _guard(() async {
    final me = _me;
    await _publish(me, stats);
    return _load(me);
  });

  @override
  Future<String> create(String name, SquadStats stats) => _guard(() async {
    await _publish(_me, stats);
    final rows = await _client.rpc(
      'create_squad',
      params: {'squad_name': name.trim()},
    );
    return (rows as List).single['squad_id'] as String;
  });

  @override
  Future<String?> join(String code, SquadStats stats) => _guard(() async {
    await _publish(_me, stats);
    final id = await _client.rpc(
      'join_squad',
      params: {'invite_code': cleanInviteCode(code)},
    );
    return id as String?;
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

  @override
  Future<String> friendCode() =>
      _guard(() async => await _client.rpc('friend_code') as String);

  @override
  Future<bool> addFriend(String code, SquadStats stats) => _guard(() async {
    await _publish(_me, stats);
    final id = await _client.rpc(
      'add_friend',
      params: {'friend_code': cleanInviteCode(code)},
    );
    return id != null;
  });

  @override
  Future<void> removeFriend(String personId) => _guard(() async {
    final me = _me;
    final (a, b) = me.compareTo(personId) < 0 ? (me, personId) : (personId, me);
    await _client.from('friendships').delete().eq('user_a', a).eq('user_b', b);
  });

  @override
  Future<String> addSharedExpense({
    required String? squadId,
    required String description,
    required String category,
    required int totalCents,
    required String paidBy,
    required SplitKind kind,
    required Map<String, int> shares,
  }) => _guard(() async {
    final id = await _client.rpc(
      'add_shared_expense',
      params: {
        'squad': squadId,
        'description': description,
        'category': category,
        'total_cents': totalCents,
        'paid_by': paidBy,
        'split_kind': kind.name,
        'shares': [
          for (final e in shares.entries)
            {'user_id': e.key, 'share_cents': e.value},
        ],
      },
    );
    return id as String;
  });

  @override
  Future<void> deleteSharedExpense(String id) => _guard(
    () => _client.rpc('delete_shared_expense', params: {'target': id}),
  );

  @override
  Future<void> deleteSettlement(String id) =>
      _guard(() => _client.rpc('delete_settlement', params: {'target': id}));

  @override
  Future<void> recordSettlements(List<SettlementItem> items) => _guard(
    () => _client.rpc(
      'record_settlements',
      params: {
        'items': [
          for (final i in items)
            {
              'squad_id': i.squadId,
              'from_user': i.from,
              'to_user': i.to,
              'amount_cents': i.amountCents,
            },
        ],
      },
    ),
  );

  @override
  Future<void> setSimplifyDebts(String squadId, bool on) => _guard(
    () => _client.rpc(
      'set_simplify_debts',
      params: {'squad': squadId, 'simplify': on},
    ),
  );

  @override
  Future<void> removeMember(String squadId, String personId) => _guard(
    () => _client.rpc(
      'remove_squad_member',
      params: {'squad': squadId, 'person': personId},
    ),
  );

  @override
  Future<void> block(String personId) =>
      _guard(() => _client.rpc('block_user', params: {'person': personId}));

  @override
  Future<void> unblock(String personId) =>
      _guard(() => _client.rpc('unblock_user', params: {'person': personId}));

  @override
  Future<List<Person>> blockedPeople() => _guard(() async {
    final rows = await _client.rpc('blocked_people') as List;
    return [
      for (final r in rows)
        Person(
          id: r['id'] as String,
          name: r['first_name'] as String,
          emoji: r['emoji'] as String,
        ),
    ];
  });

  @override
  Future<void> report({
    String? personId,
    String? squadId,
    required ReportReason reason,
    String? details,
  }) => _guard(
    () => _client.rpc(
      'report',
      params: {
        'person': personId,
        'squad': squadId,
        'reason': reason.key,
        'details': details,
      },
    ),
  );

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

  /// Squads (with members), friendships, splits and settle-ups, then the
  /// profiles of everyone they mention.
  Future<SocialData> _load(String me) async {
    final mine = await _client
        .from('squad_members')
        .select('squad_id, joined_at, squads(name, simplify_debts, created_by)')
        .eq('user_id', me)
        .order('joined_at');
    final squadIds = [for (final r in mine) r['squad_id'] as String];
    final memberRows = squadIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _client
              .from('squad_members')
              .select(
                'squad_id, user_id, '
                'profiles(first_name, emoji, streak, no_delivery_days)',
              )
              .inFilter('squad_id', squadIds)
              .order('joined_at');
    final friendships = await _client
        .from('friendships')
        .select('user_a, user_b');
    final expenseRows = await _client
        .from('shared_expenses')
        .select('*, expense_shares(user_id, share_cents)')
        .order('created_at', ascending: false)
        .limit(500);
    final settlementRows = await _client
        .from('settlements')
        .select()
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .limit(500);

    final squads = <Squad>[];
    for (final r in mine) {
      final members = [
        for (final m in memberRows)
          if (m['squad_id'] == r['squad_id'] &&
              m['profiles'] is Map<String, dynamic>)
            _member(m, me),
      ];
      final createdBy = (r['squads'] as Map?)?['created_by'] as String?;
      squads.add(
        Squad(
          id: r['squad_id'] as String,
          name: (r['squads'] as Map?)?['name'] as String? ?? 'Squad',
          simplifyDebts:
              (r['squads'] as Map?)?['simplify_debts'] as bool? ?? true,
          members: members,
          // Members come oldest first, as the server picks the owner.
          ownerId: members.any((m) => m.userId == createdBy)
              ? createdBy
              : members.firstOrNull?.userId,
        ),
      );
    }

    final direct = {
      for (final f in friendships)
        f['user_a'] == me ? f['user_b'] as String : f['user_a'] as String,
    };
    final expenses = [for (final r in expenseRows) _expense(r)];
    final settlements = [for (final r in settlementRows) _settlement(r)];
    final mentioned = <String>{
      ...direct,
      for (final e in expenses) ...[e.paidBy, ...e.shares.keys],
      for (final s in settlements) ...[s.from, s.to],
    }..remove(me);

    // Names: squadmates come with their profile; look up the rest.
    final names = <String, (String, String)>{
      for (final s in squads)
        for (final m in s.members) m.userId: (m.name, m.emoji),
    };
    final missing = mentioned.where((id) => !names.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      final rows = await _client
          .from('profiles')
          .select('id, first_name, emoji')
          .inFilter('id', missing);
      for (final r in rows) {
        names[r['id'] as String] = (
          r['first_name'] as String,
          r['emoji'] as String,
        );
      }
    }

    final people = <String, Person>{};
    for (final id in {...mentioned, ...names.keys}..remove(me)) {
      final (name, emoji) = names[id] ?? ('Someone', '🙂');
      people[id] = Person(
        id: id,
        name: name,
        emoji: emoji,
        direct: direct.contains(id),
        squadIds: {
          for (final s in squads)
            if (s.members.any((m) => m.userId == id)) s.id,
        },
      );
    }
    return SocialData(
      me: me,
      squads: squads,
      people: people,
      expenses: expenses,
      settlements: settlements,
    );
  }

  static SquadMember _member(Map<String, dynamic> row, String me) {
    final p = row['profiles'] as Map<String, dynamic>;
    return SquadMember(
      userId: row['user_id'] as String,
      name: p['first_name'] as String,
      emoji: p['emoji'] as String,
      streak: p['streak'] as int,
      noDeliveryDays: [
        for (final d in p['no_delivery_days'] as List) d as bool,
      ],
      isMe: row['user_id'] == me,
    );
  }

  static SharedExpense _expense(Map<String, dynamic> r) => SharedExpense(
    id: r['id'] as String,
    squadId: r['squad_id'] as String?,
    createdBy: r['created_by'] as String?,
    paidBy: r['paid_by'] as String,
    description: r['description'] as String,
    category: r['category'] as String? ?? 'other',
    kind: SplitKind.values.asNameMap()[r['split_kind']] ?? SplitKind.equal,
    totalCents: r['total_cents'] as int,
    createdAt: DateTime.parse(r['created_at'] as String),
    deleted: r['deleted_at'] != null,
    shares: {
      for (final s in (r['expense_shares'] as List? ?? const []))
        (s as Map)['user_id'] as String: s['share_cents'] as int,
    },
  );

  static Settlement _settlement(Map<String, dynamic> r) => Settlement(
    id: r['id'] as String,
    squadId: r['squad_id'] as String?,
    from: r['from_user'] as String,
    to: r['to_user'] as String,
    amountCents: r['amount_cents'] as int,
    createdBy: r['created_by'] as String?,
    createdAt: DateTime.parse(r['created_at'] as String),
  );

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
        'too_many_friends' => 'You\'ve reached 500 friends.',
        'own_code' => 'That\'s your own friend code.',
        'not_friends' => 'You can only split with friends.',
        'not_all_friends' =>
          'Everyone in a split has to be friends with each other. '
              'Add each other as friends, or split inside a squad.',
        'too_many_splits' => 'That\'s a lot of splits. Try again in an hour.',
        'too_many_settlements' =>
          'That\'s a lot of settle-ups. Try again in an hour.',
        'not_in_squad' => 'Everyone has to be in the squad for a squad split.',
        'shares_dont_add_up' => 'The parts don\'t add up to the total.',
        'not_allowed' =>
          'You can only remove splits and settle-ups you\'re in.',
        'not_owner' => 'Only the squad\'s owner can remove people.',
        'cant_join' => 'You can\'t join this squad.',
        'too_many_blocks' => 'You\'ve blocked 500 people.',
        'too_many_reports' =>
          'You\'ve sent a lot of reports today. Try again tomorrow.',
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
