import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seafarer_assistant/core/api_client.dart';
import 'package:seafarer_assistant/core/token_store.dart';
import 'package:seafarer_assistant/data/db.dart';
import 'package:seafarer_assistant/data/repositories.dart';

/// A fake /v1/sync server with the same version rules as backend/sa_backend/api/routes_sync.py.
class FakeSyncServer {
  final rows = <String, Map<String, dynamic>>{};
  var offline = false;

  Future<http.Response> handle(http.Request req) async {
    if (offline) throw http.ClientException('offline');
    if (req.url.path == '/v1/sync/push') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      final applied = <String, int>{};
      final conflicts = <Map<String, dynamic>>[];
      for (final c in (body['certificates'] as List).cast<Map<String, dynamic>>()) {
        final id = c['id'] as String;
        final server = rows[id];
        if (server == null) {
          rows[id] = {...c, 'version': 1, 'updated_at': DateTime.now().toUtc().toIso8601String()};
          applied[id] = 1;
        } else if (server['version'] != c['version']) {
          conflicts.add({'id': id, 'entity': 'certificate', 'server': server});
        } else {
          rows[id] = {...c, 'version': (server['version'] as int) + 1, 'updated_at': DateTime.now().toUtc().toIso8601String()};
          applied[id] = rows[id]!['version'] as int;
        }
      }
      return http.Response(jsonEncode({'applied': applied, 'conflicts': conflicts}), 200);
    }
    if (req.url.path == '/v1/sync/changes') {
      return http.Response(
          jsonEncode({'certificates': rows.values.toList(), 'sea_service': [], 'cursor': DateTime.now().toUtc().toIso8601String()}),
          200);
    }
    return http.Response('{"detail":"not found"}', 404);
  }
}

void main() {
  late AppDatabase db;
  late FakeSyncServer server;
  late CertificateRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    server = FakeSyncServer();
    final tokens = MemoryTokenStore()
      ..access = 'a'
      ..refresh = 'r';
    final api = ApiClient(baseUrl: 'http://test', tokens: tokens, client: MockClient(server.handle));
    repo = CertificateRepository(api, db);
  });

  tearDown(() => db.close());

  test('add offline, sync on reconnect, no data loss', () async {
    server.offline = true;
    final id = await repo.save(type: 'medical', expiryDate: '2027-01-01', number: 'FAKE-1');
    await expectLater(repo.sync(), throwsA(isA<ApiException>().having((e) => e.offline, 'offline', true)));
    expect((await repo.byId(id))!.dirty, isTrue); // kept locally

    server.offline = false;
    final report = await repo.sync();
    expect(report.pushed, 1);
    final c = (await repo.byId(id))!;
    expect(c.dirty, isFalse);
    expect(c.version, 1);
    expect(server.rows[id]!['number'], 'FAKE-1');
  });

  test('edit on two devices: conflict is surfaced, nothing silently overwritten', () async {
    final id = await repo.save(type: 'coc', expiryDate: '2027-01-01');
    await repo.sync();
    // another device changes it on the server
    server.rows[id] = {...server.rows[id]!, 'expiry_date': '2028-06-01', 'version': 2};
    // this device edits from version 1
    await repo.save(id: id, type: 'coc', expiryDate: '2026-12-31');
    final report = await repo.sync();
    expect(report.conflicts, 1);
    final local = (await repo.byId(id))!;
    expect(local.expiryDate, '2026-12-31'); // local edit kept
    expect(local.conflictJson, contains('2028-06-01')); // server copy shown to the user
    expect(server.rows[id]!['expiry_date'], '2028-06-01'); // server not overwritten

    await repo.resolveConflict(id, keepMine: true);
    await repo.sync();
    expect(server.rows[id]!['expiry_date'], '2026-12-31');
    expect((await repo.byId(id))!.conflictJson, isNull);
  });

  test('choosing the other version applies the server copy', () async {
    final id = await repo.save(type: 'coc', expiryDate: '2027-01-01');
    await repo.sync();
    server.rows[id] = {...server.rows[id]!, 'expiry_date': '2028-06-01', 'version': 2};
    await repo.save(id: id, type: 'coc', expiryDate: '2026-12-31');
    await repo.sync();
    await repo.resolveConflict(id, keepMine: false);
    final local = (await repo.byId(id))!;
    expect(local.expiryDate, '2028-06-01');
    expect(local.dirty, isFalse);
  });

  test('delete syncs as a tombstone and the row leaves the wallet', () async {
    final id = await repo.save(type: 'passport');
    await repo.sync();
    await repo.softDelete(id);
    expect(await repo.watchAll().first, isEmpty);
    await repo.sync();
    expect(server.rows[id]!['deleted_at'], isNotNull);
  });

  test('certificates added on another device arrive', () async {
    server.rows['remote-1'] = {
      'id': 'remote-1',
      'type': 'cdc',
      'expiry_date': '2031-02-14',
      'version': 3,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final report = await repo.sync();
    expect(report.pulled, 1);
    expect((await repo.byId('remote-1'))!.version, 3);
  });
}
