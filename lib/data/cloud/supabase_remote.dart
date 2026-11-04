import 'package:supabase/supabase.dart';

import '../sync/sync_remote.dart';

/// [SyncRemote] backed by the `poulplan_records` table and the
/// `poulplan_push` function (see supabase/).
class SupabaseRemote implements SyncRemote {
  SupabaseRemote(this._client);

  final SupabaseClient _client;

  static const _table = 'poulplan_records';

  RemoteRecord _toRecord(Map<String, dynamic> row) => RemoteRecord(
    entity: row['entity'] as String,
    id: row['id'] as String,
    data: Map<String, dynamic>.from(row['data'] as Map),
    deleted: row['deleted'] as bool,
    rev: (row['rev'] as num).toInt(),
  );

  @override
  Future<List<RemoteRecord>> pull(int afterRev, {int limit = 500}) async {
    final rows = await _client
        .from(_table)
        .select('entity, id, data, deleted, rev')
        .gt('rev', afterRev)
        .order('rev', ascending: true)
        .limit(limit);
    return rows.map(_toRecord).toList();
  }

  @override
  Future<List<PushResult>> push(List<PushItem> items) async {
    final rows = await _client.rpc(
      'poulplan_push',
      params: {'p_records': items.map((i) => i.toJson()).toList()},
    ) as List;
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        (
          entity: r['entity'] as String,
          id: r['id'] as String,
          rev: (r['rev'] as num).toInt(),
          conflict: r['conflict'] as bool,
        ),
    ];
  }

  @override
  Future<RemoteRecord?> fetch(String entity, String id) async {
    final row = await _client
        .from(_table)
        .select('entity, id, data, deleted, rev')
        .eq('entity', entity)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : _toRecord(row);
  }
}
