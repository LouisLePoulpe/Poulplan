import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/domain/sync/hlc.dart';
import 'package:poulplan/domain/sync/merge.dart';
import 'package:poulplan/domain/sync/sync_record.dart';

void main() {
  group('Hlc', () {
    test('format and parse round-trip, lexicographic order = time order', () {
      final a = Hlc(1700000000000, 0, 'nodeA');
      final b = Hlc(1700000000000, 1, 'nodeA');
      final c = Hlc(1700000000001, 0, 'nodeA');
      expect(Hlc.parse(a.toString()), a);
      final sorted = [c.toString(), a.toString(), b.toString()]..sort();
      expect(sorted, [a.toString(), b.toString(), c.toString()]);
    });

    test('node id breaks ties', () {
      expect(Hlc(5, 0, 'a').compareTo(Hlc(5, 0, 'b')), lessThan(0));
    });

    test('tick is strictly increasing even if the wall clock stalls or '
        'goes back', () {
      var now = 1000;
      final clock = HlcClock('n', now: () => now);
      final t1 = clock.tick();
      final t2 = clock.tick();
      now = 900; // clock moved backwards
      final t3 = clock.tick();
      now = 2000;
      final t4 = clock.tick();
      expect(t1 < t2 && t2 < t3 && t3 < t4, isTrue);
      expect(t4, Hlc(2000, 0, 'n'));
    });

    test('receive moves past a remote clock that is ahead', () {
      final clock = HlcClock('local', now: () => 1000);
      clock.receive(Hlc(5000, 3, 'remote'));
      final next = clock.tick();
      expect(next > Hlc(5000, 3, 'remote'), isTrue);
      expect(next.node, 'local');
    });
  });

  group('mergeRecords', () {
    String v(int ms) => Hlc(ms, 0, 'x').toString();

    SyncRecord record(
      Map<String, Object?> fields,
      Map<String, String> versions,
    ) => SyncRecord(
      entity: 'event',
      id: 'e1',
      fields: fields,
      versions: versions,
    );

    test('changes to different fields merge without conflict', () {
      final base = {'title': v(1), 'location': v(1)};
      final local = record(
        {'title': 'Réunion projet', 'location': 'Salle A'},
        {'title': v(10), 'location': v(1)},
      );
      final remote = record(
        {'title': 'Réunion', 'location': 'Salle B'},
        {'title': v(1), 'location': v(12)},
      );
      final result = mergeRecords(local: local, remote: remote, base: base);
      expect(result.conflicts, isEmpty);
      expect(result.record.fields, {
        'title': 'Réunion projet',
        'location': 'Salle B',
      });
      expect(result.record.versions, {'title': v(10), 'location': v(12)});
    });

    test('the same field changed on both sides is a real conflict', () {
      final base = {'title': v(1)};
      final local = record({'title': 'Dentiste'}, {'title': v(10)});
      final remote = record({'title': 'Orthodontiste'}, {'title': v(12)});
      final result = mergeRecords(local: local, remote: remote, base: base);
      expect(result.conflicts.single.field, 'title');
      expect(result.conflicts.single.localValue, 'Dentiste');
      expect(result.conflicts.single.remoteValue, 'Orthodontiste');
      // Provisional value: the most recent one.
      expect(result.record.fields['title'], 'Orthodontiste');
    });

    test('the same new value on both sides is not a conflict', () {
      final base = {'title': v(1)};
      final local = record({'title': 'Yoga'}, {'title': v(10)});
      final remote = record({'title': 'Yoga'}, {'title': v(12)});
      final result = mergeRecords(local: local, remote: remote, base: base);
      expect(result.conflicts, isEmpty);
      expect(result.record.versions['title'], v(12));
    });

    test('only the remote side changed: remote values win', () {
      final base = {'title': v(1)};
      final local = record({'title': 'A'}, {'title': v(1)});
      final remote = record({'title': 'B'}, {'title': v(5)});
      final result = mergeRecords(local: local, remote: remote, base: base);
      expect(result.record.fields['title'], 'B');
      expect(result.conflicts, isEmpty);
    });

    test('without a base, unversioned fields yield to versioned ones', () {
      // A default category seeded on both devices, renamed on one.
      final local = record({'name': 'Travail'}, {});
      final remote = record({'name': 'Boulot'}, {'name': v(5)});
      final result = mergeRecords(local: local, remote: remote, base: null);
      expect(result.record.fields['name'], 'Boulot');
      expect(result.conflicts, isEmpty);
    });

    test('without a base, both versioned and different is a conflict', () {
      final local = record({'name': 'Perso'}, {'name': v(4)});
      final remote = record({'name': 'Privé'}, {'name': v(5)});
      final result = mergeRecords(local: local, remote: remote, base: null);
      expect(result.conflicts.single.field, 'name');
    });

    test('deleted on one side, edited on the other: conflict, kept', () {
      final base = {'title': v(1), deletedField: v(1)};
      final local = record(
        {'title': 'Cours', deletedField: true},
        {'title': v(1), deletedField: v(10)},
      );
      final remote = record(
        {'title': 'Cours (salle B)', deletedField: false},
        {'title': v(12), deletedField: v(1)},
      );
      final result = mergeRecords(local: local, remote: remote, base: base);
      expect(result.conflicts.single.field, deletedField);
      expect(result.record.deleted, isFalse);
      expect(result.record.fields['title'], 'Cours (salle B)');
    });

    test('deleted on one side, untouched on the other: deleted', () {
      final base = {'title': v(1), deletedField: v(1)};
      final local = record(
        {'title': 'Cours', deletedField: false},
        {'title': v(1), deletedField: v(1)},
      );
      final remote = record(
        {'title': 'Cours', deletedField: true},
        {'title': v(1), deletedField: v(8)},
      );
      final result = mergeRecords(local: local, remote: remote, base: base);
      expect(result.conflicts, isEmpty);
      expect(result.record.deleted, isTrue);
    });

    test('fields unknown locally (newer app version) are kept', () {
      final base = {'title': v(1)};
      final local = record({'title': 'A'}, {'title': v(1)});
      final remote = record(
        {'title': 'A', 'futureField': 42},
        {'title': v(1), 'futureField': v(9)},
      );
      final result = mergeRecords(local: local, remote: remote, base: base);
      expect(result.record.fields['futureField'], 42);
    });

    test('structured values are compared by content', () {
      final base = {'tags': v(1)};
      final local = record(
        {
          'tags': ['a', 'b'],
        },
        {'tags': v(10)},
      );
      final remote = record(
        {
          'tags': ['a', 'b'],
        },
        {'tags': v(11)},
      );
      expect(
        mergeRecords(local: local, remote: remote, base: base).conflicts,
        isEmpty,
      );
    });
  });

  group('SyncRecord json', () {
    test('round-trip through the server payload', () {
      final record = SyncRecord(
        entity: 'event',
        id: 'e1',
        fields: {'title': 'Réunion', 'startUtc': 1, deletedField: false},
        versions: {'title': 'v1'},
      );
      final payload = record.toPayload();
      expect(payload['id'], 'e1');
      expect(SyncRecord.fromPayload('event', payload), record);
    });
  });
}
