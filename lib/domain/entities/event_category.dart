import 'package:meta/meta.dart';

@immutable
class EventCategory {
  const EventCategory({
    required this.id,
    required this.name,
    required this.color,
    this.sortOrder = 0,
  });

  final String id;
  final String name;

  /// ARGB color.
  final int color;
  final int sortOrder;

  @override
  bool operator ==(Object other) =>
      other is EventCategory &&
      other.id == id &&
      other.name == name &&
      other.color == color &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(id, name, color, sortOrder);
}
