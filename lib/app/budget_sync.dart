/// Budget sync: the whole budget, encrypted on the device with a key made
/// from a passphrase only the person knows, so the server stores data it
/// can't read. Another device signed in to the same account downloads it
/// and unlocks it with the same passphrase.
///
/// It's a snapshot, not a live merge: each save uploads everything, and
/// when two devices both changed, the most recent change wins.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// The encrypted budget as stored on the server, with what's needed to
/// make the key again from the passphrase. None of it reveals the budget.
class EncryptedBudget {
  const EncryptedBudget({
    required this.ciphertext,
    required this.nonce,
    required this.salt,
    required this.iterations,
  });

  /// AES-256-GCM output with its tag, base64.
  final String ciphertext;
  final String nonce;

  /// PBKDF2-HMAC-SHA256 salt (base64) and rounds for the passphrase.
  final String salt;
  final int iterations;
}

/// What the server holds for this account, without downloading the budget.
class RemoteBudgetInfo {
  const RemoteBudgetInfo({
    required this.version,
    required this.updatedAt,
    required this.salt,
  });

  /// Goes up by one with every upload.
  final int version;
  final DateTime updatedAt;

  /// Changes only when the passphrase is changed or sync starts over.
  final String salt;
}

/// The server side. Only the signed-in account can read or write its row.
abstract interface class BudgetBackupStore {
  Future<RemoteBudgetInfo?> info();
  Future<(EncryptedBudget, RemoteBudgetInfo)?> download();

  /// Saves [budget] if the server is still at [expectedVersion] (null: no
  /// copy yet). Returns the new info, or null when another device saved
  /// first.
  Future<RemoteBudgetInfo?> upload(
    EncryptedBudget budget, {
    required int? expectedVersion,
  });

  Future<void> delete();
}

/// What this device remembers about sync, kept in the Keychain / Keystore:
/// the key (so the passphrase is typed once per device), and how far it
/// has synced.
class LocalSyncState {
  const LocalSyncState({
    required this.userId,
    required this.key,
    required this.salt,
    required this.version,
    this.changedAt,
  });

  final String userId;

  /// The derived 256-bit key, base64. Never the passphrase.
  final String key;
  final String salt;

  /// The server version this device last uploaded or downloaded.
  final int version;

  /// When this device last changed the budget without uploading it yet.
  final DateTime? changedAt;

  bool get dirty => changedAt != null;

  LocalSyncState copyWith({int? version, DateTime? changedAt, bool? clean}) =>
      LocalSyncState(
        userId: userId,
        key: key,
        salt: salt,
        version: version ?? this.version,
        changedAt: clean == true ? null : changedAt ?? this.changedAt,
      );

  Map<String, Object?> toJson() => {
    'userId': userId,
    'key': key,
    'salt': salt,
    'version': version,
    'changedAt': changedAt?.toUtc().toIso8601String(),
  };

  static LocalSyncState fromJson(Map<String, Object?> json) => LocalSyncState(
    userId: json['userId'] as String,
    key: json['key'] as String,
    salt: json['salt'] as String,
    version: json['version'] as int,
    changedAt: json['changedAt'] == null
        ? null
        : DateTime.parse(json['changedAt'] as String),
  );
}

abstract interface class LocalSyncStore {
  Future<LocalSyncState?> read();
  Future<void> write(LocalSyncState state);
  Future<void> clear();
}

/// Kept in memory only: tests, and platforms without sign-in.
class MemorySyncStore implements LocalSyncStore {
  LocalSyncState? state;

  @override
  Future<LocalSyncState?> read() async => state;

  @override
  Future<void> write(LocalSyncState state) async => this.state = state;

  @override
  Future<void> clear() async => state = null;
}

/// No server: sync is never offered.
class NoBudgetBackups implements BudgetBackupStore {
  const NoBudgetBackups();

  @override
  Future<RemoteBudgetInfo?> info() async => null;

  @override
  Future<(EncryptedBudget, RemoteBudgetInfo)?> download() async => null;

  @override
  Future<RemoteBudgetInfo?> upload(
    EncryptedBudget budget, {
    required int? expectedVersion,
  }) async => null;

  @override
  Future<void> delete() async {}
}

/// The passphrase didn't open the synced budget.
class WrongPassphraseException implements Exception {
  const WrongPassphraseException();
}

/// Sync failed for a reason worth telling the person.
class SyncException implements Exception {
  const SyncException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// PBKDF2 to turn the passphrase into a key, AES-256-GCM to seal the
/// budget. The account ID is bound in as associated data, so a copy can't
/// be moved to someone else's account and opened there.
class BudgetCipher {
  const BudgetCipher({this.iterations = defaultIterations});

  /// OWASP's 2023 advice for PBKDF2-HMAC-SHA256.
  static const defaultIterations = 600000;

  final int iterations;

  static final _aes = AesGcm.with256bits();

  static String newSalt() {
    final random = math.Random.secure();
    return base64Encode(List.generate(16, (_) => random.nextInt(256)));
  }

  Future<String> deriveKey(String passphrase, String salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final key = await pbkdf2.deriveKeyFromPassword(
      password: passphrase,
      nonce: base64Decode(salt),
    );
    return base64Encode(await key.extractBytes());
  }

  Future<EncryptedBudget> seal(
    Map<String, Object?> snapshot, {
    required String key,
    required String salt,
    required String userId,
  }) async {
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(snapshot)),
      secretKey: SecretKey(base64Decode(key)),
      aad: utf8.encode(userId),
    );
    return EncryptedBudget(
      ciphertext: base64Encode([...box.cipherText, ...box.mac.bytes]),
      nonce: base64Encode(box.nonce),
      salt: salt,
      iterations: iterations,
    );
  }

  /// Throws [WrongPassphraseException] when [key] doesn't fit.
  Future<Map<String, Object?>> open(
    EncryptedBudget budget, {
    required String key,
    required String userId,
  }) async {
    final bytes = base64Decode(budget.ciphertext);
    if (bytes.length < 16) throw const WrongPassphraseException();
    try {
      final plain = await _aes.decrypt(
        SecretBox(
          bytes.sublist(0, bytes.length - 16),
          nonce: base64Decode(budget.nonce),
          mac: Mac(bytes.sublist(bytes.length - 16)),
        ),
        secretKey: SecretKey(base64Decode(key)),
        aad: utf8.encode(userId),
      );
      return (jsonDecode(utf8.decode(plain)) as Map).cast<String, Object?>();
    } on SecretBoxAuthenticationError {
      throw const WrongPassphraseException();
    }
  }
}

enum SyncStatus {
  /// Not signed in, or sync never turned on for this account.
  off,

  /// The account has a synced budget this device can't open yet.
  needsPassphrase,

  /// On and up to date (or about to upload a change).
  on,
}

/// Error message for a new passphrase, or null when it's fine.
String? validatePassphrase(String passphrase) {
  if (passphrase.length < 8) return 'Use at least 8 characters.';
  if (passphrase.length > 200) return 'That\'s too long.';
  return null;
}

/// Runs sync for one device: uploads after local changes (a few seconds
/// later, so a burst of edits is one upload), downloads newer copies, and
/// settles the case where both changed by keeping the most recent.
class BudgetSyncController extends ChangeNotifier {
  BudgetSyncController({
    required this.store,
    required this.local,
    required this.exportBudget,
    required this.importBudget,
    required this.userId,
    this.cipher = const BudgetCipher(),
    this.uploadDelay = const Duration(seconds: 4),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final BudgetBackupStore store;
  final LocalSyncStore local;
  final BudgetCipher cipher;
  final Future<Map<String, Object?>> Function() exportBudget;
  final Future<void> Function(Map<String, Object?> snapshot) importBudget;

  /// The signed-in account, or null.
  final String? Function() userId;
  final Duration uploadDelay;
  final DateTime Function() _clock;

  SyncStatus _status = SyncStatus.off;
  DateTime? _lastSynced;
  String? _error;
  bool _busy = false;
  Timer? _pending;
  Future<void> _queue = Future.value();
  bool _disposed = false;

  SyncStatus get status => _status;

  /// When this device last matched the synced copy.
  DateTime? get lastSynced => _lastSynced;

  /// Why the last sync didn't work, if it didn't. Cleared on success.
  String? get error => _error;
  bool get busy => _busy;

  /// Runs [task] after any sync work already going, one at a time.
  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<T> _run<T>(Future<T> Function() task) => _serial(() async {
    _busy = true;
    _notify();
    try {
      final value = await task();
      _error = null;
      return value;
    } on WrongPassphraseException {
      rethrow;
    } on SyncException catch (e) {
      _error = e.message;
      rethrow;
    } on Object catch (e) {
      debugPrint('Budget sync failed: $e');
      _error = 'Couldn\'t sync. Check your connection; it\'ll try again.';
      throw SyncException(_error!);
    } finally {
      _busy = false;
      _notify();
    }
  });

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Brings this device and the synced copy together. Safe to call any
  /// time (launch, sign-in, coming back to the app); errors end up in
  /// [error].
  Future<void> check() async {
    try {
      await _run(_check);
    } on Object {
      // Shown through [error].
    }
  }

  Future<void> _check() async {
    final user = userId();
    var state = await local.read();
    if (user == null) {
      _status = SyncStatus.off;
      return;
    }
    if (state != null && state.userId != user) {
      await local.clear();
      state = null;
    }
    final remote = await store.info();
    if (state == null) {
      _status = remote == null ? SyncStatus.off : SyncStatus.needsPassphrase;
      return;
    }
    if (remote == null) {
      // Another device turned sync off and deleted the copy.
      await local.clear();
      _status = SyncStatus.off;
      return;
    }
    if (remote.salt != state.salt) {
      // The passphrase was changed (or sync started over) elsewhere.
      await local.clear();
      _status = SyncStatus.needsPassphrase;
      return;
    }
    _status = SyncStatus.on;
    if (remote.version != state.version) {
      final mineIsNewer =
          state.dirty && state.changedAt!.isAfter(remote.updatedAt);
      if (mineIsNewer) {
        await _upload(state, expectedVersion: remote.version);
      } else {
        await _download(state);
      }
    } else if (state.dirty) {
      await _upload(state, expectedVersion: state.version);
    }
    _lastSynced = _clock();
  }

  Future<void> _upload(
    LocalSyncState state, {
    required int? expectedVersion,
  }) async {
    final startedAt = _clock();
    final sealed = await cipher.seal(
      await exportBudget(),
      key: state.key,
      salt: state.salt,
      userId: state.userId,
    );
    final info = await store.upload(sealed, expectedVersion: expectedVersion);
    if (info == null) {
      // Another device saved in between: start over from the top.
      return _check();
    }
    final now = await local.read() ?? state;
    final changedSince =
        now.changedAt != null && now.changedAt!.isAfter(startedAt);
    await local.write(
      now.copyWith(version: info.version, clean: !changedSince),
    );
  }

  Future<void> _download(LocalSyncState state) async {
    final found = await store.download();
    if (found == null) return;
    final (budget, info) = found;
    final snapshot = await cipher.open(
      budget,
      key: state.key,
      userId: state.userId,
    );
    await importBudget(snapshot);
    await local.write(state.copyWith(version: info.version, clean: true));
  }

  /// Turns sync on with a new [passphrase] when the account has no synced
  /// copy yet, uploading this device's budget.
  Future<void> turnOn(String passphrase) => _run(() async {
    final user = _requireUser();
    final salt = BudgetCipher.newSalt();
    final key = await cipher.deriveKey(passphrase, salt);
    final state = LocalSyncState(
      userId: user,
      key: key,
      salt: salt,
      version: 0,
      changedAt: _clock(),
    );
    await local.write(state);
    _status = SyncStatus.on;
    await _upload(state, expectedVersion: null);
    _lastSynced = _clock();
  });

  /// Opens the account's synced copy with [passphrase] and replaces this
  /// device's budget with it. Throws [WrongPassphraseException].
  Future<void> unlock(String passphrase) => _run(() async {
    final user = _requireUser();
    final remote = await store.info();
    if (remote == null) {
      throw const SyncException('There\'s no synced budget to bring here.');
    }
    final key = await cipher.deriveKey(passphrase, remote.salt);
    final found = await store.download();
    if (found == null) {
      throw const SyncException('There\'s no synced budget to bring here.');
    }
    final (budget, info) = found;
    final snapshot = await cipher.open(budget, key: key, userId: user);
    await importBudget(snapshot);
    await local.write(
      LocalSyncState(
        userId: user,
        key: key,
        salt: remote.salt,
        version: info.version,
      ),
    );
    _status = SyncStatus.on;
    _lastSynced = _clock();
  });

  /// For a forgotten passphrase: deletes the synced copy and syncs this
  /// device's budget again under a new [passphrase].
  Future<void> startOver(String passphrase) async {
    await _run(() async {
      _requireUser();
      await store.delete();
      await local.clear();
    });
    await turnOn(passphrase);
  }

  /// Stops syncing on this device. With [deleteCopy], the synced copy is
  /// deleted too, which stops sync on every device.
  Future<void> turnOff({required bool deleteCopy}) => _run(() async {
    _pending?.cancel();
    if (deleteCopy) await store.delete();
    await local.clear();
    _status = deleteCopy ? SyncStatus.off : SyncStatus.needsPassphrase;
  });

  /// This device's budget changed: upload it shortly.
  void localChanged() {
    if (_status != SyncStatus.on) return;
    unawaited(
      _serial(() async {
        final state = await local.read();
        // The latest change time, so "most recent wins" compares the
        // right moment.
        if (state != null) {
          await local.write(state.copyWith(changedAt: _clock()));
        }
      }),
    );
    _pending?.cancel();
    _pending = Timer(uploadDelay, () => unawaited(check()));
  }

  /// Uploads a pending change now instead of after [uploadDelay]. Does
  /// nothing when no upload is waiting.
  Future<void> flush() async {
    final pending = _pending;
    if (pending == null || !pending.isActive) return;
    pending.cancel();
    await check();
  }

  /// Forgets sync on this device (signed out or erased). The synced copy
  /// stays for the next sign-in.
  Future<void> forget() => _serial(() async {
    _pending?.cancel();
    await local.clear();
    _status = SyncStatus.off;
    _lastSynced = null;
    _error = null;
    _notify();
  });

  String _requireUser() {
    final user = userId();
    if (user == null) throw const SyncException('Sign in to sync.');
    return user;
  }

  @override
  void dispose() {
    _disposed = true;
    _pending?.cancel();
    super.dispose();
  }
}
