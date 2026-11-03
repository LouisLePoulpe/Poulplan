import 'package:meta/meta.dart';

/// A calendar event as seen by the rest of the app.
///
/// Times are stored in UTC:
/// - timed events: [start]/[end] are real instants and [timeZone] is the IANA
///   zone the event was entered in;
/// - all-day events: [start]/[end] are UTC midnights encoding *floating* dates
///   (the event stays on the same dates whatever the device's zone), with
///   [end] exclusive.
@immutable
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    this.description = '',
    this.categoryId,
    this.color,
    this.location,
    this.videoLink,
    this.busy = true,
    this.allDay = false,
    required this.start,
    required this.end,
    required this.timeZone,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final String? categoryId;

  /// ARGB color overriding the category's one.
  final int? color;
  final String? location;
  final String? videoLink;

  /// Free/busy status: `true` means busy.
  final bool busy;
  final bool allDay;
  final DateTime start;
  final DateTime end;
  final String timeZone;
  final DateTime createdAt;
  final DateTime updatedAt;

  Duration get duration => end.difference(start);

  CalendarEvent copyWith({
    String? title,
    String? description,
    String? Function()? categoryId,
    int? Function()? color,
    String? Function()? location,
    String? Function()? videoLink,
    bool? busy,
    bool? allDay,
    DateTime? start,
    DateTime? end,
    String? timeZone,
    DateTime? updatedAt,
  }) {
    return CalendarEvent(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId != null ? categoryId() : this.categoryId,
      color: color != null ? color() : this.color,
      location: location != null ? location() : this.location,
      videoLink: videoLink != null ? videoLink() : this.videoLink,
      busy: busy ?? this.busy,
      allDay: allDay ?? this.allDay,
      start: start ?? this.start,
      end: end ?? this.end,
      timeZone: timeZone ?? this.timeZone,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarEvent &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      other.categoryId == categoryId &&
      other.color == color &&
      other.location == location &&
      other.videoLink == videoLink &&
      other.busy == busy &&
      other.allDay == allDay &&
      other.start == start &&
      other.end == end &&
      other.timeZone == timeZone &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    categoryId,
    color,
    location,
    videoLink,
    busy,
    allDay,
    start,
    end,
    timeZone,
    updatedAt,
  );

  @override
  String toString() =>
      'CalendarEvent($id, $title, $start → $end'
      '${allDay ? ', all day' : ''})';
}
