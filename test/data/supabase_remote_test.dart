import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:poulplan/data/cloud/supabase_remote.dart';
import 'package:supabase/supabase.dart';

void main() {
  test('records are pulled in increasing revision order', () async {
    late Uri sent;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon',
      httpClient: MockClient((request) async {
        sent = request.url;
        return http.Response('[]', 200, request: request);
      }),
    );
    addTearDown(client.dispose);
    await SupabaseRemote(client).pull(41);
    // A category must be applied before the events that use it.
    expect(sent.queryParameters['order'], 'rev.asc.nullslast');
    expect(sent.queryParameters['rev'], 'gt.41');
  });
}
