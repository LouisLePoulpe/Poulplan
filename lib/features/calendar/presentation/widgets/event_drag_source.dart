import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../domain/entities/calendar_event.dart';

/// Makes an event draggable: immediate drag with a mouse on desktop,
/// long-press drag on touch platforms (so that scrolling still works).
class EventDragSource extends StatelessWidget {
  const EventDragSource({
    super.key,
    required this.event,
    required this.feedback,
    required this.child,
  });

  final CalendarEvent event;
  final Widget feedback;
  final Widget child;

  static bool get _touch =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    if (event.kind != EventKind.event) return child;
    final dragged = Material(
      color: Colors.transparent,
      child: Opacity(opacity: 0.85, child: feedback),
    );
    final placeholder = Opacity(opacity: 0.3, child: child);
    if (_touch) {
      return LongPressDraggable<CalendarEvent>(
        data: event,
        feedback: dragged,
        childWhenDragging: placeholder,
        child: child,
      );
    }
    return Draggable<CalendarEvent>(
      data: event,
      feedback: dragged,
      childWhenDragging: placeholder,
      child: child,
    );
  }
}
