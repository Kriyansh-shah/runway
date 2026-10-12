/// The browser build keeps the database in the browser's own storage
/// (OPFS / IndexedDB), unencrypted: a key there would sit next to the data.
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

Future<QueryExecutor> openDeviceDatabase() async => driftDatabase(
  name: 'runway',
  web: DriftWebOptions(
    sqlite3Wasm: Uri.parse('sqlite3.wasm'),
    driftWorker: Uri.parse('drift_worker.js'),
  ),
);
