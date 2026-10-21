/// Opens `runway.sqlite` on phones and desktops, encrypted on phones.
///
/// SQLite is built with SQLite3MultipleCiphers (see `pubspec.yaml`). On iOS
/// and Android the whole file is encrypted with a random 256-bit key that
/// never leaves the Keychain / Keystore, so a copy of the file on its own
/// (a lost backup, a jailbroken phone's file system) is unreadable.
/// The macOS build is only used for development and stays unencrypted.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart';

Future<QueryExecutor> openDeviceDatabase() async {
  final directory = await getApplicationSupportDirectory();
  final file = File(p.join(directory.path, 'runway.sqlite'));
  final key = Platform.isIOS || Platform.isAndroid
      ? await DatabaseKey.secure().readOrCreate()
      : null;
  if (key != null) prepareEncryptedFile(file, key);
  return driftDatabase(
    name: 'runway',
    native: DriftNativeOptions(
      databasePath: () async => file.path,
      // Runs on drift's background isolate, before anything else is read.
      setup: key == null ? null : (db) => unlock(db, key),
    ),
  );
}

/// The database key, created on first use. Written before the file is ever
/// encrypted with it, so a crash in between can't lock the data away.
class DatabaseKey {
  DatabaseKey({required this.read, required this.write, this.reset});

  /// The Keychain (iOS) or Keystore-backed storage (Android).
  ///
  /// iOS: readable after the first unlock since restart, and it moves to a
  /// new iPhone with an encrypted backup, along with the file it opens.
  /// Android: not reset on an ordinary read error, which would lose the
  /// data; only when the Keystore can't open the storage at all (see
  /// [reset]).
  factory DatabaseKey.secure() {
    const storage = FlutterSecureStorage(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      aOptions: AndroidOptions(resetOnError: false),
    );
    return DatabaseKey(
      read: () => storage.read(key: _name),
      write: (key) => storage.write(key: _name, value: key),
      reset: Platform.isAndroid
          ? () => const FlutterSecureStorage(
              aOptions: AndroidOptions(resetOnError: true),
            ).deleteAll()
          : null,
    );
  }

  static const _name = 'runway.database_key';

  final Future<String?> Function() read;
  final Future<void> Function(String key) write;

  /// Clears storage the Keystore can't open: on Android, data restored from
  /// a backup or another phone arrives without the Keystore keys that
  /// unwrap it, and every read fails ("Failed to unwrap key"). The key is
  /// gone for good then; the file it opened is moved aside by
  /// [prepareEncryptedFile] and the app starts fresh instead of hanging
  /// on the launch screen. Null on iOS, where a read can fail for passing
  /// reasons (before the first unlock) and the key must never be wiped.
  final Future<void> Function()? reset;

  Future<String> readOrCreate() async {
    final existing = await _readSurvivingBrokenStorage();
    if (existing != null) return existing;
    final random = Random.secure();
    final key = hex([for (var i = 0; i < 32; i++) random.nextInt(256)]);
    await write(key);
    return key;
  }

  Future<String?> _readSurvivingBrokenStorage() async {
    try {
      return await read();
    } on PlatformException catch (first) {
      final reset = this.reset;
      if (reset == null) rethrow;
      try {
        return await read();
      } on PlatformException {
        debugPrint('Secure storage unreadable, starting fresh: $first');
        await reset();
        return null;
      }
    }
  }

  @visibleForTesting
  static String hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Must be the first statement on a new connection. [key] is hex, so it
/// can't break out of the quotes.
void unlock(CommonDatabase db, String key) => db.execute("PRAGMA key = '$key'");

/// What [prepareEncryptedFile] found.
enum DatabaseFile {
  /// No file yet: SQLite creates it, encrypted, on first write.
  none,

  /// Already encrypted with the key.
  encrypted,

  /// A plain file from before encryption; now encrypted in place.
  migrated,

  /// Can't be opened with the key (say, restored without its key). Moved
  /// aside next to the original name so nothing is deleted, and the app
  /// starts fresh instead of failing on every launch.
  unreadable,
}

/// Makes sure [file] is encrypted with [key] before drift opens it.
DatabaseFile prepareEncryptedFile(File file, String key) {
  if (!file.existsSync()) return DatabaseFile.none;
  if (_isPlain(file)) {
    final db = sqlite3.open(file.path);
    try {
      // SQLite3MultipleCiphers encrypts an unencrypted file in place.
      db.execute("PRAGMA rekey = '$key'");
    } finally {
      db.close();
    }
    return DatabaseFile.migrated;
  }
  final db = sqlite3.open(file.path);
  var readable = false;
  try {
    unlock(db, key);
    db.select('SELECT count(*) FROM sqlite_master');
    readable = true;
  } on SqliteException {
    // Wrong key, or not a database at all.
  } finally {
    db.close();
  }
  if (readable) return DatabaseFile.encrypted;
  final stamp = DateTime.now().millisecondsSinceEpoch;
  file.renameSync('${file.path}.unreadable-$stamp');
  return DatabaseFile.unreadable;
}

/// Every unencrypted SQLite file starts with this header; an encrypted one
/// starts with random bytes.
bool _isPlain(File file) {
  final raf = file.openSync();
  try {
    final header = raf.readSync(16);
    return header.length == 16 &&
        utf8.decode(header, allowMalformed: true) == 'SQLite format 3\u0000';
  } finally {
    raf.closeSync();
  }
}
