import 'dart:convert';

import 'package:meta/meta.dart';

import '../calendar/day.dart';
import '../entities/calendar_event.dart';

/// Zones of the French school calendar bundled with the app.
const schoolZones = ['A', 'B', 'C', 'Corse'];

@immutable
class SchoolHolidayPeriod {
  const SchoolHolidayPeriod({
    required this.zone,
    required this.name,
    required this.firstDay,
    required this.endExclusive,
  });

  final String zone;
  final String name;
  final Day firstDay;

  /// Day classes resume.
  final Day endExclusive;

  Day get lastDay => endExclusive.addDays(-1);

  CalendarEvent toEvent() => CalendarEvent(
    id: 'school:$zone@$firstDay',
    title: name,
    allDay: true,
    busy: false,
    start: firstDay.toUtcMidnight(),
    end: endExclusive.toUtcMidnight(),
    timeZone: 'UTC',
    kind: EventKind.schoolHoliday,
    createdAt: firstDay.toUtcMidnight(),
    updatedAt: firstDay.toUtcMidnight(),
  );
}

/// French school holidays, read from the bundled open-data extract
/// (`assets/data/school_holidays_fr.json`).
class SchoolHolidayCalendar {
  SchoolHolidayCalendar(this.periods);

  factory SchoolHolidayCalendar.fromJson(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return SchoolHolidayCalendar([
      for (final p in (json['periods'] as List).cast<Map<String, dynamic>>())
        SchoolHolidayPeriod(
          zone: p['zone'] as String,
          name: p['name'] as String,
          firstDay: Day.parse(p['start'] as String),
          endExclusive: Day.parse(p['end'] as String),
        ),
    ]);
  }

  static final empty = SchoolHolidayCalendar(const []);

  final List<SchoolHolidayPeriod> periods;

  /// Periods of [zone] overlapping [from]…[to].
  List<SchoolHolidayPeriod> between(String zone, Day from, Day to) => [
    for (final p in periods)
      if (p.zone == zone &&
          !p.lastDay.isBefore(from) &&
          !p.firstDay.isAfter(to))
        p,
  ];
}
