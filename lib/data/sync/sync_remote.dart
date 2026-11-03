import 'package:meta/meta.dart';

@immutable
class RemoteRecord {
  const RemoteRecord({
    required this.entity,
    required this.id,
    required this.data,
    required this.deleted,
    required this.rev,
  });

  final String entity;
  final String id;
  final Map<String, dynamic> data;
  final bool deleted;
  final int rev;
}

@immutable
class PushItem {
  const PushItem({
    required this.entity,
    required this.id,
    required this.data,
    required this.deleted,
    required this.baseRev,
  });

  final String entity;
  final String id;
  final Map<String, dynamic> data;
  final bool deleted;

  /// Server revision the change is based on; null for a new record.
  final int? baseRev;

  Map<String, dynamic> toJson() => {
    'entity': entity,
    'id': id,
    'data': data,
    'deleted': deleted,
    'base_rev': baseRev,
  };
}

typedef PushResult = ({String entity, String id, int rev, bool conflict});

/// The cloud side of the synchronization (Supabase in the app, in-memory in
/// tests). Network failures throw.
abstract interface class SyncRemote {
  /// Records with a revision greater than [afterRev], in revision order.
  Future<List<RemoteRecord>> pull(int afterRev, {int limit = 500});

  /// Conditional writes (see `poulplan_push` in supabase/).
  Future<List<PushResult>> push(List<PushItem> items);

  Future<RemoteRecord?> fetch(String entity, String id);
}
