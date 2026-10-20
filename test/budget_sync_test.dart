import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/budget_sync.dart';

import 'fake_budget_server.dart';

/// A device: its budget is just a map here.
class Device {
  Device(this.server, {this.user = 'u1'}) {
    sync = BudgetSyncController(
      store: server,
      local: MemorySyncStore(),
      exportBudget: () async => {...budget},
      importBudget: (s) async => budget = {...s},
      userId: () => user,
      cipher: const BudgetCipher(iterations: 1000),
      uploadDelay: Duration.zero,
      clock: () => now,
    );
  }

  final FakeServer server;
  String? user;
  Map<String, Object?> budget = {'expenses': <Object?>[]};
  DateTime now = DateTime.utc(2026, 10, 20, 12);
  late final BudgetSyncController sync;

  /// Changes the budget and lets the upload happen.
  Future<void> spend(String what) async {
    budget = {
      'expenses': [...(budget['expenses'] as List), what],
    };
    sync.localChanged();
    await sync.flush();
  }
}

void main() {
  late FakeServer server;
  setUp(() => server = FakeServer());

  test('the server only ever gets ciphertext', () async {
    final phone = Device(server)..budget = {'note': 'Rent \$900'};
    await phone.sync.turnOn('correct horse');

    expect(server.budget!.ciphertext, isNot(contains('Rent')));
    expect(server.budget!.ciphertext, isNot(contains('900')));
    expect(phone.sync.status, SyncStatus.on);
  });

  test('a new device unlocks the budget with the passphrase', () async {
    final phone = Device(server);
    await phone.spend('coffee');
    await phone.sync.turnOn('correct horse');

    final web = Device(server);
    await web.sync.check();
    expect(web.sync.status, SyncStatus.needsPassphrase);

    await expectLater(
      web.sync.unlock('wrong horse'),
      throwsA(isA<WrongPassphraseException>()),
    );
    expect(web.budget['expenses'], isEmpty);

    await web.sync.unlock('correct horse');
    expect(web.budget['expenses'], ['coffee']);
    expect(web.sync.status, SyncStatus.on);
  });

  test('changes flow both ways', () async {
    final phone = Device(server);
    await phone.sync.turnOn('correct horse');
    final web = Device(server);
    await web.sync.unlock('correct horse');

    await phone.spend('lunch');
    await web.sync.check();
    expect(web.budget['expenses'], ['lunch']);

    web.now = web.now.add(const Duration(minutes: 1));
    await web.spend('books');
    await phone.sync.check();
    expect(phone.budget['expenses'], ['lunch', 'books']);
  });

  test('when both changed, the most recent change wins', () async {
    final phone = Device(server);
    await phone.sync.turnOn('correct horse');
    final web = Device(server);
    await web.sync.unlock('correct horse');

    // The web goes offline, changes something, then the phone changes
    // something later and uploads.
    server.offline = true;
    await web.spend('older');
    server.offline = false;
    phone.now = web.now.add(const Duration(minutes: 5));
    server.clock = () => phone.now;
    await phone.spend('newer');

    await web.sync.check();
    expect(web.budget['expenses'], ['newer']);
  });

  test('a copy from another account can\'t be opened', () async {
    final phone = Device(server);
    await phone.sync.turnOn('correct horse');
    final stranger = Device(server, user: 'u2');
    await expectLater(
      stranger.sync.unlock('correct horse'),
      throwsA(isA<WrongPassphraseException>()),
    );
  });

  test('offline: the error shows and the change uploads later', () async {
    final phone = Device(server);
    await phone.sync.turnOn('correct horse');
    server.offline = true;
    await phone.spend('taxi');
    expect(phone.sync.error, isNotNull);

    server.offline = false;
    await phone.sync.check();
    expect(phone.sync.error, isNull);
    final web = Device(server);
    await web.sync.unlock('correct horse');
    expect(web.budget['expenses'], ['taxi']);
  });

  test('starting over replaces the copy and locks out the old key', () async {
    final phone = Device(server);
    await phone.sync.turnOn('forgotten');
    final web = Device(server);
    await web.sync.unlock('forgotten');

    phone.budget = {
      'expenses': ['fresh'],
    };
    await phone.sync.startOver('remembered');
    await web.sync.check();
    expect(web.sync.status, SyncStatus.needsPassphrase);
    await web.sync.unlock('remembered');
    expect(web.budget['expenses'], ['fresh']);
  });

  test('deleting the copy turns sync off everywhere', () async {
    final phone = Device(server);
    await phone.sync.turnOn('correct horse');
    final web = Device(server);
    await web.sync.unlock('correct horse');

    await phone.sync.turnOff(deleteCopy: true);
    await web.sync.check();
    expect(server.row, isNull);
    expect(web.sync.status, SyncStatus.off);
  });

  test('signed out: sync is off', () async {
    final phone = Device(server)..user = null;
    await phone.sync.check();
    expect(phone.sync.status, SyncStatus.off);
  });

  test('passphrases need 8 characters', () {
    expect(validatePassphrase('short'), isNotNull);
    expect(validatePassphrase('long enough'), isNull);
  });
}
