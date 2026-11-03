import 'package:meta/meta.dart';

import '../calendar/day.dart';
import 'calendar_event.dart';

/// A birthday entered manually (or imported from contacts later).
@immutable
class Birthday {
  const Birthday({
    required this.id,
    required this.name,
    required this.month,
    required this.day,
    this.birthYear,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int month;
  final int day;
  final int? birthYear;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The date celebrated in [year] (28 February for a 29 February birthday
  /// in a common year).
  Day dateIn(int year) {
    final candidate = Day(year, month, day);
    return candidate.month == month ? candidate : Day(year, month + 1, 0);
  }

  /// All-day display events between [from] and [to].
  List<CalendarEvent> occurrences(Day from, Day to) => [
    for (var year = from.year; year <= to.year; year++)
      if (birthYear == null || year >= birthYear!)
        if (!dateIn(year).isBefore(from) && !dateIn(year).isAfter(to))
          CalendarEvent(
            id: 'birthday:$id@$year',
            title: _title(year),
            allDay: true,
            start: dateIn(year).toUtcMidnight(),
            end: dateIn(year).addDays(1).toUtcMidnight(),
            timeZone: 'UTC',
            busy: false,
            kind: EventKind.birthday,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
  ];

  String _title(int year) {
    if (birthYear == null) return 'Anniversaire de $name';
    final age = year - birthYear!;
    if (age == 0) return 'Naissance de $name';
    return 'Anniversaire de $name ($age ${age == 1 ? 'an' : 'ans'})';
  }

  @override
  bool operator ==(Object other) =>
      other is Birthday &&
      other.id == id &&
      other.name == name &&
      other.month == month &&
      other.day == day &&
      other.birthYear == birthYear;

  @override
  int get hashCode => Object.hash(id, name, month, day, birthYear);
}
