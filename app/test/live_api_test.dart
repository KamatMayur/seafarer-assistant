/// End-to-end check of the app's data layer against a running local API (real data). Skipped by default.
///   set LIVE_API=1 and API_LOG=<path to the API's log file>, then: flutter test test/live_api_test.dart
/// The sign-in code is read from the API log ("DEV LOGIN CODE ..."), so the API must run with SA_ENV=dev.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seafarer_assistant/core/api_client.dart';
import 'package:seafarer_assistant/core/token_store.dart';
import 'package:seafarer_assistant/data/db.dart';
import 'package:seafarer_assistant/data/models.dart';
import 'package:seafarer_assistant/data/repositories.dart';

void main() {
  final live = Platform.environment['LIVE_API'] == '1';
  final base = Platform.environment['API_BASE'] ?? 'http://127.0.0.1:8000';

  test('sign in, profile, feed, search, document, certificate sync', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final api = ApiClient(baseUrl: base, tokens: MemoryTokenStore());
    final auth = AuthRepository(api, db);
    final email = 'live.test.${DateTime.now().millisecondsSinceEpoch}@example.com';

    await auth.startEmailLogin(email);
    final log = await File(Platform.environment['API_LOG']!).readAsString();
    final code = RegExp('DEV LOGIN CODE for ${RegExp.escape(email)}: (\\d{6})').allMatches(log).last.group(1)!;
    expect(await auth.verify(email, code, consentCore: true, consentEmail: false), isTrue);

    final profiles = ProfileRepository(api, db);
    final meta = await profiles.meta();
    expect(meta.mmds, contains('mumbai'));
    final p = await profiles.update(Profile(department: 'engine', level: 'officer', homeMmd: 'kolkata', examGrades: ['meo_class_2']));
    expect(p.isComplete, isTrue);

    // Alerts are created by the worker when documents are processed; a brand-new user has none yet,
    // so the feed call must simply succeed and be empty.
    final feed = FeedRepository(api, db);
    expect(await feed.refresh(), isEmpty);

    final docs = DocumentRepository(api, db);
    final found = await docs.search(q: 'CoC');
    expect(found.total, greaterThan(0));
    final detail = await docs.detail(found.items.first.id);
    expect(detail.detail.pdfUrl, startsWith('https://dgma.gov.in/'));
    expect(detail.fromCache, isFalse);

    final certs = CertificateRepository(api, db);
    await certs.save(type: 'coc', subtype: 'MEO Class II', number: 'FAKE-LIVE-1', expiryDate: '2030-01-01');
    final r = await certs.sync();
    expect(r.pushed, 1);
    expect(r.conflicts, 0);

    await auth.deleteAccount(); // leave no test user behind
    await db.close();
  }, skip: live ? false : 'set LIVE_API=1 to run against a local API');
}
