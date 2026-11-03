import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/data/db/app_database.dart';
import 'package:poulplan/data/repositories/event_repository.dart';
import 'package:poulplan/domain/calendar/day.dart';

void main() {
  test('events survive closing and reopening the database file', () async {
    final dir = await Directory.systemTemp.createTemp('poulplan_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/poulplan.db');

    var db = AppDatabase(NativeDatabase(file));
    final created = await EventRepository(db).create(
      title: 'Persistant',
      allDay: true,
      start: DateTime.utc(2026, 12, 24),
      end: DateTime.utc(2026, 12, 26),
      timeZone: 'Europe/Paris',
    );
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final reopened = EventRepository(db);
    expect(await reopened.findById(created.id), created);
    final inRange = await reopened
        .watchBetween(Day(2026, 12, 1), Day(2026, 12, 31))
        .first;
    expect(inRange.single.title, 'Persistant');
  });
}
