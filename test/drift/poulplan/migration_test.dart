// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:poulplan/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v4.dart' as v4;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        // Migrations always go to the latest version (no step-by-step
        // intermediate schemas).
        for (final toVersion
            in versions.skip(i + 1).where((v) => v == versions.last)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  test(
    'migration from v1 to the latest keeps events and fills searchText',
    () async {
      const old = v1.EventsData(
        id: 'e1',
        title: 'Fête de Noël',
        description: "À l'école",
        categoryId: null,
        color: null,
        location: 'Lyon',
        videoLink: null,
        busy: 1,
        allDay: 0,
        startUtc: 1000,
        endUtc: 2000,
        timeZone: 'Europe/Paris',
        createdAt: 1,
        updatedAt: 2,
        deletedAt: null,
      );
      const expected = v4.EventsData(
        id: 'e1',
        title: 'Fête de Noël',
        description: "À l'école",
        categoryId: null,
        color: null,
        location: 'Lyon',
        videoLink: null,
        busy: 1,
        allDay: 0,
        startUtc: 1000,
        endUtc: 2000,
        timeZone: 'Europe/Paris',
        rrule: null,
        holidayRule: 'none',
        seriesId: null,
        originalStartUtc: null,
        cancelled: 0,
        recurrenceEndUtc: null,
        reminders: '[]',
        searchText: "fete de noel a l'ecole lyon",
        createdAt: 1,
        updatedAt: 2,
        deletedAt: null,
      );

      await verifier.testWithDataIntegrity(
        oldVersion: 1,
        newVersion: 4,
        createOld: v1.DatabaseAtV1.new,
        createNew: v4.DatabaseAtV4.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) => batch.insert(oldDb.events, old),
        validateItems: (newDb) async {
          expect(await newDb.select(newDb.events).get(), [expected]);
        },
      );
    },
  );
}
