/// The encrypted budget on Supabase (`budget_backups`, one row per
/// account; see supabase/migrations). Row-level security lets only the
/// owner read or write it, and it's ciphertext either way.
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'budget_sync.dart';

class SupabaseBudgetBackups implements BudgetBackupStore {
  const SupabaseBudgetBackups();

  SupabaseClient get _client => Supabase.instance.client;

  String get _me {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const SyncException('Sign in to sync.');
    return id;
  }

  static RemoteBudgetInfo _info(Map<String, dynamic> row) => RemoteBudgetInfo(
    version: row['version'] as int,
    updatedAt: DateTime.parse(row['updated_at'] as String),
    salt: row['salt'] as String,
  );

  @override
  Future<RemoteBudgetInfo?> info() async {
    final row = await _client
        .from('budget_backups')
        .select('version, updated_at, salt')
        .eq('user_id', _me)
        .maybeSingle();
    return row == null ? null : _info(row);
  }

  @override
  Future<(EncryptedBudget, RemoteBudgetInfo)?> download() async {
    final row = await _client
        .from('budget_backups')
        .select()
        .eq('user_id', _me)
        .maybeSingle();
    if (row == null) return null;
    return (
      EncryptedBudget(
        ciphertext: row['ciphertext'] as String,
        nonce: row['nonce'] as String,
        salt: row['salt'] as String,
        iterations: row['iterations'] as int,
      ),
      _info(row),
    );
  }

  @override
  Future<RemoteBudgetInfo?> upload(
    EncryptedBudget budget, {
    required int? expectedVersion,
  }) async {
    final me = _me;
    final fields = {
      'ciphertext': budget.ciphertext,
      'nonce': budget.nonce,
      'salt': budget.salt,
      'iterations': budget.iterations,
    };
    if (expectedVersion == null) {
      try {
        final row = await _client
            .from('budget_backups')
            .insert({...fields, 'user_id': me, 'version': 1})
            .select('version, updated_at, salt')
            .single();
        return _info(row);
      } on PostgrestException catch (e) {
        // Another device created it first.
        if (e.code == '23505') return null;
        rethrow;
      }
    }
    // Only if nobody else saved since: the version is the lock.
    final rows = await _client
        .from('budget_backups')
        .update({...fields, 'version': expectedVersion + 1})
        .eq('user_id', me)
        .eq('version', expectedVersion)
        .select('version, updated_at, salt');
    return rows.isEmpty ? null : _info(rows.single);
  }

  @override
  Future<void> delete() =>
      _client.from('budget_backups').delete().eq('user_id', _me);
}

/// This device's sync key and progress, in the Keychain / Keystore (the
/// browser's storage on the web).
class SecureSyncStore implements LocalSyncStore {
  const SecureSyncStore();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    aOptions: AndroidOptions(resetOnError: false),
  );
  static const _key = 'budget_sync';

  @override
  Future<LocalSyncState?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    return LocalSyncState.fromJson(
      (jsonDecode(raw) as Map).cast<String, Object?>(),
    );
  }

  @override
  Future<void> write(LocalSyncState state) =>
      _storage.write(key: _key, value: jsonEncode(state.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
