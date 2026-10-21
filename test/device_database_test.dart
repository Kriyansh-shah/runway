import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/database.dart';
import 'package:runway/app/device_database.dart';
import 'package:runway/app/drift_repository.dart';
import 'package:sqlite3/sqlite3.dart';

/// Real files on disk, opened with the same SQLite3MultipleCiphers build
/// the phones use.
void main() {
  final key = DatabaseKey.hex(List.generate(32, (i) => i));
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('runway_crypto');
    file = File('${dir.path}/runway.sqlite');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  /// A plain, unencrypted file like the ones installed before encryption.
  void writePlainFile() {
    final db = sqlite3.open(file.path);
    db.execute(
      "CREATE TABLE notes (text TEXT); INSERT INTO notes VALUES ('rent')",
    );
    db.close();
  }

  String readNote({String? withKey}) {
    final db = sqlite3.open(file.path);
    try {
      if (withKey != null) unlock(db, withKey);
      return db.select('SELECT text FROM notes').single['text'] as String;
    } finally {
      db.close();
    }
  }

  bool looksPlain() =>
      latin1.decode(file.readAsBytesSync().take(15).toList()) ==
      'SQLite format 3';

  test('no file yet: nothing to do', () {
    expect(prepareEncryptedFile(file, key), DatabaseFile.none);
  });

  test('a plain file from before is encrypted in place', () {
    writePlainFile();
    expect(looksPlain(), isTrue);

    expect(prepareEncryptedFile(file, key), DatabaseFile.migrated);
    expect(looksPlain(), isFalse);
    expect(readNote(withKey: key), 'rent');
    expect(() => readNote(), throwsA(isA<SqliteException>()));

    expect(prepareEncryptedFile(file, key), DatabaseFile.encrypted);
    expect(readNote(withKey: key), 'rent');
  });

  test('a file the key can\'t open is moved aside, never deleted', () {
    writePlainFile();
    prepareEncryptedFile(file, key);
    final otherKey = DatabaseKey.hex(List.filled(32, 7));

    expect(prepareEncryptedFile(file, otherKey), DatabaseFile.unreadable);
    expect(file.existsSync(), isFalse);
    final kept = dir.listSync().whereType<File>().single;
    expect(kept.path, contains('runway.sqlite.unreadable-'));
  });

  test('the app\'s data is unreadable on disk without the key', () async {
    Future<DriftBudgetRepository> open() async => DriftBudgetRepository(
      RunwayDatabase(NativeDatabase(file, setup: (db) => unlock(db, key))),
      clock: () => DateTime(2026, 10, 2, 15),
    );

    var repo = await open();
    final seeded = await repo.load();
    await repo.close();

    expect(looksPlain(), isFalse);
    final bytes = latin1.decode(file.readAsBytesSync());
    expect(bytes, isNot(contains(seeded.term.name)));
    expect(bytes, isNot(contains(seeded.upcoming.first.name)));

    repo = await open();
    expect((await repo.load()).term.name, seeded.term.name);
    await repo.close();
  });

  test('the key is made once and kept', () async {
    String? stored;
    var writes = 0;
    final keys = DatabaseKey(
      read: () async => stored,
      write: (k) async {
        stored = k;
        writes++;
      },
    );

    final first = await keys.readOrCreate();
    expect(first, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(await keys.readOrCreate(), first);
    expect(writes, 1);

    // Another install gets a different key.
    String? elsewhere;
    final other = DatabaseKey(
      read: () async => elsewhere,
      write: (k) async => elsewhere = k,
    );
    expect(await other.readOrCreate(), isNot(first));
  });

  test('unreadable Android storage is cleared and a new key made', () async {
    var stored = 'old';
    var broken = true;
    var resets = 0;
    final key = DatabaseKey(
      read: () async {
        if (broken) throw PlatformException(code: 'Failed to unwrap key');
        return stored;
      },
      write: (k) async => stored = k,
      reset: () async {
        resets++;
        broken = false;
      },
    );
    final fresh = await key.readOrCreate();
    expect(resets, 1);
    expect(fresh, hasLength(64));
    expect(stored, fresh);
  });

  test('without a reset (iOS), a read error is never wiped away', () async {
    final key = DatabaseKey(
      read: () async => throw PlatformException(code: 'locked'),
      write: (_) async => fail('must not write a new key'),
    );
    await expectLater(key.readOrCreate(), throwsA(isA<PlatformException>()));
  });
}
