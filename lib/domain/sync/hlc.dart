import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Hybrid logical clock timestamp: wall-clock milliseconds, a counter for
/// events within the same millisecond, and the id of the device.
///
/// Its string form sorts lexicographically in time order, so versions can be
/// compared as plain strings.
@immutable
class Hlc implements Comparable<Hlc> {
  const Hlc(this.millis, this.counter, this.node);

  factory Hlc.parse(String text) {
    final parts = text.split(':');
    if (parts.length < 3) throw FormatException('Invalid HLC', text);
    return Hlc(
      int.parse(parts[0]),
      int.parse(parts[1], radix: 36),
      parts.sublist(2).join(':'),
    );
  }

  final int millis;
  final int counter;
  final String node;

  @override
  int compareTo(Hlc other) {
    if (millis != other.millis) return millis.compareTo(other.millis);
    if (counter != other.counter) return counter.compareTo(other.counter);
    return node.compareTo(other.node);
  }

  bool operator <(Hlc other) => compareTo(other) < 0;
  bool operator >(Hlc other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      other.millis == millis &&
      other.counter == counter &&
      other.node == node;

  @override
  int get hashCode => Object.hash(millis, counter, node);

  @override
  String toString() =>
      '${millis.toString().padLeft(15, '0')}:'
      '${counter.toRadixString(36).padLeft(4, '0')}:$node';
}

/// Produces strictly increasing [Hlc]s for this device.
class HlcClock {
  HlcClock(this.node, {int Function()? now, Hlc? last})
    : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
      _last = last ?? Hlc(0, 0, node);

  final String node;
  final int Function() _now;
  Hlc _last;

  Hlc get last => _last;

  Hlc tick() {
    final physical = _now();
    _last = physical > _last.millis
        ? Hlc(physical, 0, node)
        : Hlc(_last.millis, _last.counter + 1, node);
    return _last;
  }

  /// Takes a remote timestamp into account so that later local ticks are
  /// ordered after it.
  void receive(Hlc remote) {
    final physical = _now();
    final millis = math.max(physical, math.max(_last.millis, remote.millis));
    final int counter;
    if (millis == _last.millis && millis == remote.millis) {
      counter = math.max(_last.counter, remote.counter) + 1;
    } else if (millis == _last.millis) {
      counter = _last.counter + 1;
    } else if (millis == remote.millis) {
      counter = remote.counter + 1;
    } else {
      counter = 0;
    }
    _last = Hlc(millis, counter, node);
  }
}
