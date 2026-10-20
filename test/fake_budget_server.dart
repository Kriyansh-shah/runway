import 'package:runway/app/budget_sync.dart';

/// One account's row on the server, shared by every device in a test.
class FakeServer implements BudgetBackupStore {
  EncryptedBudget? budget;
  RemoteBudgetInfo? row;
  DateTime Function() clock = DateTime.now;
  bool offline = false;

  void _check() {
    if (offline) throw Exception('offline');
  }

  @override
  Future<RemoteBudgetInfo?> info() async {
    _check();
    return row;
  }

  @override
  Future<(EncryptedBudget, RemoteBudgetInfo)?> download() async {
    _check();
    return row == null ? null : (budget!, row!);
  }

  @override
  Future<RemoteBudgetInfo?> upload(
    EncryptedBudget budget, {
    required int? expectedVersion,
  }) async {
    _check();
    if (row?.version != expectedVersion) return null;
    this.budget = budget;
    return row = RemoteBudgetInfo(
      version: (row?.version ?? 0) + 1,
      updatedAt: clock(),
      salt: budget.salt,
    );
  }

  @override
  Future<void> delete() async {
    _check();
    budget = null;
    row = null;
  }
}
