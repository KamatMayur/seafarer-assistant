import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:seafarer_assistant/core/config.dart';
import 'package:seafarer_assistant/core/providers.dart';
import 'package:seafarer_assistant/data/db.dart';
import 'package:seafarer_assistant/data/models.dart';
import 'package:seafarer_assistant/domain/expiry.dart';
import 'package:seafarer_assistant/domain/feed_grouping.dart';
import 'package:seafarer_assistant/features/feed/feed_screen.dart';
import 'package:seafarer_assistant/features/onboarding/welcome_screen.dart';
import 'package:seafarer_assistant/features/wallet/wallet_screen.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => child),
    GoRoute(path: '/sign-in', builder: (_, _) => const Scaffold(body: Text('SIGN IN PAGE'))),
    GoRoute(path: '/wallet/:id', builder: (_, _) => const Scaffold(body: Text('CERT PAGE'))),
  ]);
  return ProviderScope(overrides: overrides, child: MaterialApp.router(routerConfig: router));
}

void main() {
  testWidgets('welcome: shows the unofficial notice and needs consent before continuing', (tester) async {
    // Tall window: list items below the fold are not built, so the Continue button must be on screen.
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const WelcomeScreen()));
    expect(find.text(AppConfig.unofficialNotice), findsOneWidget);
    final button = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.tap(find.text('I agree to the privacy policy (required)'));
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('SIGN IN PAGE'), findsOneWidget);
  });

  testWidgets('welcome: long text at 200% scale does not overflow', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: _wrap(const WelcomeScreen()),
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet groups certificates by expiry status', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final today = todayIst(); // the wallet groups by India date, whatever the machine's timezone
    String day(int offset) => formatDay(today.add(Duration(days: offset)));

    Future<void> add(String id, String type, String? expiry) => db.into(db.certificates).insert(
        CertificatesCompanion.insert(id: id, type: type, expiryDate: Value(expiry), updatedAt: DateTime.now()));
    await add('1', 'medical', day(-3));
    await add('2', 'coc', day(40));
    await add('3', 'cdc', day(2000));
    await add('4', 'stcw_basic', null);

    await tester.pumpWidget(_wrap(const WalletScreen(), overrides: [
      databaseProvider.overrideWithValue(db),
      metaProvider.overrideWith((ref) => Meta.fromJson({
            'cert_types': {'medical': 'Medical fitness', 'coc': 'CoC', 'cdc': 'CDC', 'stcw_basic': 'STCW basic safety'},
          })),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('EXPIRED (1)'), findsOneWidget);
    expect(find.text('EXPIRING WITHIN 90 DAYS (1)'), findsOneWidget);
    expect(find.text('VALID (1)'), findsOneWidget);
    expect(find.text('NO EXPIRY DATE (1)'), findsOneWidget);
    expect(find.textContaining('Expired 3 days ago'), findsOneWidget);
    expect(find.textContaining('not synced yet'), findsWidgets);

    // Unmount so Drift's live query is cancelled, then close the database outside the fake test clock
    // (closing inside it never completes and hangs the following tests).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });

  testWidgets('feed card shows critical badge, why, and certificate flag on one card', (tester) async {
    final doc = {
      'id': 'D1',
      'title': 'FAKE Advisory for the safety of Indian seafarers',
      'circular_number': '47 of 2026',
      'published_date': '2026-08-05',
      'doc_type': 'advisory',
      'priority': 'critical',
      'status': 'processed',
      'summary_short': 'x',
      'action_required': true,
      'action_deadline': '2026-08-20',
    };
    final row = FeedItem(
      alertId: 'A1',
      kind: 'new_document',
      priority: 'critical',
      createdAt: DateTime(2026, 8, 5),
      read: false,
      readDirty: false,
      reason: 'Safety/security advisory for all seafarers',
      documentId: 'D1',
      documentJson: jsonEncode(doc),
    );
    final main = FeedAlert(alertId: 'A1', kind: 'new_document', priority: 'critical', createdAt: row.createdAt, read: false, documentId: 'D1', reason: row.reason);
    final impact = FeedAlert(alertId: 'A2', kind: 'cert_impact', priority: 'normal', createdAt: row.createdAt, read: false, documentId: 'D1');
    var opened = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FeedCardTile(card: FeedCard(main, [impact]), row: row, selected: false, onOpen: () => opened = true),
      ),
    ));
    expect(find.text('CRITICAL'), findsOneWidget);
    expect(find.text('FAKE Advisory for the safety of Indian seafarers'), findsOneWidget);
    expect(find.text('May affect your certificate'), findsOneWidget);
    expect(find.textContaining('Action by 20 Aug 2026'), findsOneWidget);
    expect(find.textContaining('Why: Safety/security advisory'), findsOneWidget);
    await tester.tap(find.byType(InkWell));
    expect(opened, isTrue);
  });
}
