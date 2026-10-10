/// Full user journey on the real Windows app against a running local API with real data.
///
///   API (separate port, log to a file, SA_ENV=dev so login codes are logged):
///     $env:SA_ENV='dev'; .venv\Scripts\uvicorn sa_backend.api.app:app --port 8001 *> data\it-api.log
///   App (cd app):
///     flutter test integration_test -d windows --dart-define=API_BASE=http://127.0.0.1:8001 `
///       --dart-define=API_LOG=D:\path\to\data\it-api.log
///
/// Uses an in-memory database and in-memory tokens, so the demo's saved data is never touched. The test user
/// deletes their own account at the end.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:seafarer_assistant/app.dart';
import 'package:seafarer_assistant/core/background.dart';
import 'package:seafarer_assistant/core/file_vault.dart';
import 'package:seafarer_assistant/core/providers.dart';
import 'package:seafarer_assistant/core/token_store.dart';
import 'package:seafarer_assistant/data/db.dart';
import 'package:seafarer_assistant/features/document/document_screen.dart';
import 'package:seafarer_assistant/features/feed/feed_screen.dart';

const apiLog = String.fromEnvironment('API_LOG');

Future<void> waitFor(WidgetTester t, Finder f, {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 250));
    if (f.evaluate().isNotEmpty) return;
  }
  // Show what is on screen instead, so a failure explains itself.
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText() ?? '')
      .where((s) => s.trim().isNotEmpty)
      .take(40)
      .join(' | ');
  throw TestFailure('Timed out waiting for $f. On screen: $texts');
}

Future<String> loginCodeFor(String email) async {
  final re = RegExp('DEV LOGIN CODE for ${RegExp.escape(email)}: (\\d{6})');
  for (var i = 0; i < 40; i++) {
    final text = await File(apiLog).readAsString();
    final m = re.allMatches(text);
    if (m.isNotEmpty) return m.last.group(1)!;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw TestFailure('No login code for $email in $apiLog');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign up, profile, feed, document, wallet, search, report, delete account', (t) async {
    expect(apiLog, isNotEmpty, reason: 'pass --dart-define=API_LOG=...');
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      // Own vault key and folder: 'Delete account' must not wipe the real app's certificate key.
      fileVaultProvider.overrideWithValue(FileVault(
        keyName: 'sa_file_vault_key_integration_test',
        baseDir: () async => Directory.systemTemp.createTemp('sa_it_vault'),
      )),
    ]);
    // As main.dart: sync once signed in.
    container.listen<SessionState>(sessionProvider, (_, next) {
      if (next == SessionState.ready) container.read(backgroundSyncProvider).start();
    });
    await t.pumpWidget(UncontrolledProviderScope(container: container, child: const SeafarerApp()));

    // 1. Welcome + consent
    await waitFor(t, find.text('I agree to the privacy policy (required)'));
    await t.tap(find.text('I agree to the privacy policy (required)'));
    await t.pump();
    await t.tap(find.text('Continue'));

    // 2. Email code sign-in
    final email = 'it.${DateTime.now().millisecondsSinceEpoch}@example.com';
    await waitFor(t, find.widgetWithText(TextField, 'Email'));
    await t.enterText(find.widgetWithText(TextField, 'Email'), email);
    await t.tap(find.text('Send code'));
    await waitFor(t, find.widgetWithText(TextField, 'Code'));
    await t.enterText(find.widgetWithText(TextField, 'Code'), await loginCodeFor(email));
    await t.tap(find.widgetWithText(FilledButton, 'Sign in'));

    // 3. Profile: engine officer
    await waitFor(t, find.text('Tell us about you'));
    await waitFor(t, find.widgetWithText(ChoiceChip, 'Engine'));
    await t.tap(find.widgetWithText(ChoiceChip, 'Engine'));
    await t.tap(find.widgetWithText(ChoiceChip, 'Officer'));
    await t.pump();
    await t.scrollUntilVisible(find.text('Start'), 300, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Start'));

    // 4. Feed fills with real matching circulars (backfill of the last 30 days)
    await waitFor(t, find.byType(FeedCardTile), timeout: const Duration(seconds: 60));
    expect(find.textContaining('Test version.'), findsOneWidget); // tester tips
    await t.tap(find.byType(FeedCardTile).first);
    await waitFor(t, find.text('Who is affected'));
    expect(find.text('Deadline'), findsOneWidget);
    // The PDF button is further down the document pane (lists only build what is visible).
    final docPane = find.descendant(of: find.byType(DocumentView), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.text('Open official PDF'), 400, scrollable: docPane);
    expect(find.text('Open official PDF'), findsOneWidget);

    // 5. Wallet: add a certificate expiring today -> grouped as expiring
    await t.tap(find.text('Wallet'));
    await waitFor(t, find.text('Add certificate'));
    await t.tap(find.text('Add certificate'));
    await waitFor(t, find.text('Expiry date *'));
    await t.tap(find.text('Expiry date *'));
    await waitFor(t, find.text('OK'));
    await t.tap(find.text('OK'));
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.text('Save'));
    await waitFor(t, find.text('Expires today'));
    expect(find.textContaining('EXPIRING WITHIN 90 DAYS'), findsOneWidget);

    // 6. Archive search
    await t.tap(find.text('Archive'));
    await waitFor(t, find.byType(TextField));
    await t.enterText(find.byType(TextField).first, 'CoC');
    await waitFor(t, find.byType(ListTile), timeout: const Duration(seconds: 20));

    // 7. Report a problem
    await t.tap(find.text('Settings'));
    await waitFor(t, find.text('Report a problem or suggest something'));
    final settingsList = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.text('Report a problem or suggest something'), 200, scrollable: settingsList);
    await t.drag(settingsList, const Offset(0, -150)); // away from the window's bottom edge
    await t.pumpAndSettle();
    await t.tap(find.text('Report a problem or suggest something'));
    await waitFor(t, find.text('Send'));
    await t.enterText(find.byType(TextField).last, 'FAKE integration test report');
    await t.tap(find.text('Send'));
    await waitFor(t, find.text('Thank you, your report was sent.'));

    // 8. Delete account -> back to welcome
    await t.scrollUntilVisible(find.text('Delete my account'), 300, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Delete my account'));
    await waitFor(t, find.text('Delete everything'));
    await t.tap(find.text('Delete everything'));
    await waitFor(t, find.text('I agree to the privacy policy (required)'));

    container.dispose();
    await db.close();
  });
}
