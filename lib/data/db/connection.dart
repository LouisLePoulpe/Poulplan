import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// File name of the local database, in the application support directory
/// (`~/.local/share/org.poulapp.poulplan/` on Linux).
///
/// Not `poulplan.sqlite`: an unrelated older database with that name may
/// exist in the same directory.
const databaseFileName = 'poulplan.db';

Future<String> databasePath() async =>
    p.join((await getApplicationSupportDirectory()).path, databaseFileName);

QueryExecutor openAppDatabaseConnection() => driftDatabase(
  name: 'poulplan',
  native: const DriftNativeOptions(
    databasePath: databasePath,
    shareAcrossIsolates: true,
  ),
);
