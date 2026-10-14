import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seafarer_assistant/core/api_client.dart';
import 'package:seafarer_assistant/core/token_store.dart';
import 'package:seafarer_assistant/data/db.dart';
import 'package:seafarer_assistant/data/repositories.dart';

/// A fake /v1/sync server for sea service, with the version rules of backend/sa_backend/api/routes_sync.py.
class FakeSeaServer {
  final rows = <String, Map<String, dynamic>>{};
  final pushedKeys = <String>[];
  var offline = false;

  Future<http.Response> handle(http.Request req) async {
    if (offline) throw http.ClientException('offline');
    if (req.url.path == '/v1/sync/push') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      pushedKeys.addAll(body.keys);
      final applied = <String, int>{};
      final conflicts = <Map<String, dynamic>>[];
      for (final s in (body['sea_service'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        final id = s['id'] as String;
        final server = rows[id];
        if (server == null) {
          rows[id] = {...s, 'version': 1, 'updated_at': DateTime.now().toUtc().toIso8601String()};
          applied[id] = 1;
        } else if (server['version'] != s['version']) {
          conflicts.add({'id': id, 'entity': 'sea_service', 'server': server});
        } else {
          rows[id] = {...s, 'version': (server['version'] as int) + 1, 'updated_at': DateTime.now().toUtc().toIso8601String()};
          applied[id] = rows[id]!['version'] as int;
        }
      }
      return http.Response(jsonEncode({'applied': applied, 'conflicts': conflicts}), 200);
    }
    if (req.url.path == '/v1/sync/changes') {
      return http.Response(
          jsonEncode({'certificates': [], 'sea_service': rows.values.toList(), 'cursor': DateTime.now().toUtc().toIso8601String()}),
          200);
    }
    return http.Response('{"detail":"not found"}', 404);
  }
}

void main() {
  late AppDatabase db;
  late FakeSeaServer server;
  late SeaServiceRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    server = FakeSeaServer();
    final tokens = MemoryTokenStore()
      ..access = 'a'
      ..refresh = 'r';
    repo = SeaServiceRepository(ApiClient(baseUrl: 'http://test', tokens: tokens, client: MockClient(server.handle)), db);
  });
  tearDown(() => db.close());

  test('saved offline, pushed later; only sea_service is sent', () async {
    server.offline = true;
    final id = await repo.save(vesselName: 'FAKE MV Example', signOn: '2026-01-10', rank: 'Third Officer');
    await expectLater(repo.sync(), throwsA(isA<ApiException>()));
    expect((await repo.byId(id))!.dirty, isTrue);

    server.offline = false;
    final r = await repo.sync();
    expect(r.pushed, 1);
    final row = (await repo.byId(id))!;
    expect((row.dirty, row.version), (false, 1));
    expect(server.pushedKeys, ['sea_service']);
  });

  test('edit on another device while editing here: conflict kept, never overwritten', () async {
    final id = await repo.save(vesselName: 'FAKE MV Example', signOn: '2026-01-10');
    await repo.sync();
    // the other device signs off at version 1 -> server version 2
    server.rows[id] = {...server.rows[id]!, 'sign_off': '2026-06-30', 'version': 2};
    await repo.save(id: id, vesselName: 'FAKE MV Example', signOn: '2026-01-10', signOff: '2026-07-15');
    final r = await repo.sync();
    expect(r.conflicts, 1);
    final local = (await repo.byId(id))!;
    expect(local.signOff, '2026-07-15'); // my edit is still here
    expect(jsonDecode(local.conflictJson!)['sign_off'], '2026-06-30');
    expect(server.rows[id]!['sign_off'], '2026-06-30');

    await repo.resolveConflict(id, keepMine: true);
    await repo.sync();
    expect(server.rows[id]!['sign_off'], '2026-07-15');
    expect((await repo.byId(id))!.conflictJson, isNull);
  });

  test('pull applies rows from the server and deletions sync', () async {
    server.rows['S2'] = {
      'id': 'S2',
      'vessel_name': 'FAKE MT Other',
      'sign_on': '2025-03-01',
      'sign_off': '2025-09-01',
      'ship_type': 'tanker',
      'version': 3,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await repo.sync();
    expect((await repo.byId('S2'))!.shipType, 'tanker');

    await repo.softDelete('S2');
    await repo.sync();
    expect(server.rows['S2']!['deleted_at'], isNotNull);
    expect(await repo.watchAll().first, isEmpty);
  });
}
