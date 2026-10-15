/// On-device SQLite database (via drift). Tables mirror the models in
/// `models.dart`; [DriftBudgetRepository] maps between the two.
///
/// After changing a table, regenerate `database.g.dart`:
///   dart run build_runner build
/// and add a migration step if you bumped [RunwayDatabase.schemaVersion].
library;

import 'package:drift/drift.dart';

import 'device_database.dart'
    if (dart.library.js_interop) 'device_database_web.dart';
import 'models.dart';

part 'database.g.dart';

/// Money is stored as integer cents everywhere to avoid floating-point drift.
@DataClassName('TermRow')
class Terms extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get start => dateTime()();
  DateTimeColumn get end => dateTime()();
  IntColumn get startingBalanceCents => integer()();

  /// Stored by enum *name* (added in schema 3; older terms are semesters).
  TextColumn get period => textEnum<BudgetPeriod>().withDefault(
    Constant(BudgetPeriod.semester.name),
  )();

  /// Set when a term is finished; the current term has this null.
  DateTimeColumn get archivedAt => dateTime().nullable()();
}

@DataClassName('ExpenseRow')
class Expenses extends Table {
  TextColumn get id => text()();
  IntColumn get termId => integer().references(Terms, #id)();
  IntColumn get amountCents => integer()();

  /// Stored by enum *name* — rename values only together with a migration.
  TextColumn get category => textEnum<ExpenseCategory>()();
  BoolColumn get isNeed => boolean()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// Paid from a reserved upcoming cost (added in schema 2).
  BoolColumn get isPlanned => boolean().withDefault(const Constant(false))();

  /// Soft delete, so a future "Undo" can bring it back.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// The person's own category (added in schema 5); [category] is then
  /// `other`, which is where the expense stays if the category is deleted.
  TextColumn get customCategoryId =>
      text().nullable().references(CustomCategories, #id)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A category the person made, like 🚬 Cigarettes (added in schema 5).
@DataClassName('CustomCategoryRow')
class CustomCategories extends Table {
  TextColumn get id => text()();
  TextColumn get emoji => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();

  /// Last time an expense was logged in it; the picker shows these first.
  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('UpcomingCostRow')
class UpcomingCosts extends Table {
  TextColumn get id => text()();
  IntColumn get termId => integer().references(Terms, #id)();
  TextColumn get emoji => text()();
  TextColumn get name => text()();
  IntColumn get amountCents => integer()();
  DateTimeColumn get dueDate => dateTime()();
  DateTimeColumn get paidAt => dateTime().nullable()();

  /// One month of a repeating bill (added in schema 4); null for one-offs.
  TextColumn get billId => text().nullable().references(RepeatingBills, #id)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A bill due every month. Each month's bill is an [UpcomingCosts] row
/// pointing back here; this row is how next month's gets made.
@DataClassName('RepeatingBillRow')
class RepeatingBills extends Table {
  TextColumn get id => text()();
  TextColumn get emoji => text()();
  TextColumn get name => text()();
  IntColumn get amountCents => integer()();
  DateTimeColumn get firstDue => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  /// Set when the bill is stopped; no more months are reserved after it.
  DateTimeColumn get endedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Money coming in. A row is one payment ([IncomeFrequency.once]) or a
/// repeating schedule; paydays are worked out from it, never stored.
@DataClassName('IncomeRow')
class Incomes extends Table {
  TextColumn get id => text()();
  IntColumn get termId => integer().references(Terms, #id)();
  TextColumn get name => text()();
  IntColumn get amountCents => integer()();

  /// Stored by enum *name* — rename values only together with a migration.
  TextColumn get frequency => textEnum<IncomeFrequency>()();
  DateTimeColumn get firstDate => dateTime()();

  /// Set when a repeating payment is stopped; paydays up to it still count.
  DateTimeColumn get endsOn => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// Soft delete: removed by mistake, so none of its payments count.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('BillSplitRow')
class BillSplits extends Table {
  TextColumn get id => text()();
  TextColumn get person => text()();
  IntColumn get amountCents => integer()();
  TextColumn get note => text()();
  BoolColumn get theyOweYou => boolean()();
  DateTimeColumn get createdAt => dateTime()();

  /// Settled splits are kept for history, just hidden.
  DateTimeColumn get settledAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Mock squad for now; replaced by Supabase sync later (see ROADMAP.md).
@DataClassName('FriendRow')
class Friends extends Table {
  TextColumn get id => text()();
  IntColumn get position => integer()();
  TextColumn get name => text()();
  TextColumn get emoji => text()();
  IntColumn get streak => integer()();

  /// Challenge days as "1101": 1 = stayed delivery-free.
  TextColumn get noDeliveryDays => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The signed-in user. At most one row (id = 1).
@DataClassName('SessionRow')
class Sessions extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get email => text()();
  DateTimeColumn get signedInAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Small key/value settings (e.g. when demo data was seeded).
@DataClassName('MetaRow')
class Meta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Terms,
    Expenses,
    CustomCategories,
    UpcomingCosts,
    RepeatingBills,
    Incomes,
    BillSplits,
    Friends,
    Sessions,
    Meta,
  ],
)
class RunwayDatabase extends _$RunwayDatabase {
  RunwayDatabase(super.executor);

  /// The app's real database: `runway.sqlite` in the app's private support
  /// directory, encrypted on phones (see `device_database.dart`). Queries
  /// run on a background isolate.
  static Future<RunwayDatabase> onDevice() async =>
      RunwayDatabase(await openDeviceDatabase());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // One step per version, oldest first, so any old install can catch up.
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(incomes);
        await m.addColumn(expenses, expenses.isPlanned);
      }
      if (from < 3) {
        await m.addColumn(terms, terms.period);
      }
      if (from < 4) {
        await m.createTable(repeatingBills);
        await m.addColumn(upcomingCosts, upcomingCosts.billId);
      }
      if (from < 5) {
        await m.createTable(customCategories);
        await m.addColumn(expenses, expenses.customCategoryId);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
