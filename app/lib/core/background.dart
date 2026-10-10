import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import '../domain/expiry.dart';
import 'api_client.dart';
import 'config.dart';
import 'providers.dart';

/// While the app runs: syncs the feed and certificates every 30 minutes (2 hours in data-saver mode), shows a
/// Windows toast for each new alert, and shows expiry reminders. Reminders are computed locally, so they also
/// appear offline (the server sends the same reminders to the feed when online).
class BackgroundSync {
  BackgroundSync(this.ref);
  final Ref ref;
  Timer? _timer;
  bool _running = false;

  void start() {
    _schedule();
    unawaited(runOnce());
  }

  void stop() => _timer?.cancel();

  Future<void> _schedule() async {
    _timer?.cancel();
    final saver = (await ref.read(databaseProvider).getValue('data_saver')) == 'true';
    _timer = Timer.periodic(saver ? AppConfig.dataSaverPollInterval : AppConfig.pollInterval, (_) => runOnce());
  }

  /// Safe to call any time (also from pull-to-refresh); overlapping runs are skipped.
  Future<void> runOnce() async {
    if (_running) return;
    _running = true;
    try {
      await _syncFeed();
      await _syncCertificates();
      await showDueReminders();
    } finally {
      _running = false;
    }
  }

  Future<void> _syncFeed() async {
    final notifier = ref.read(toastProvider);
    try {
      final lang = (await ref.read(profileRepoProvider).cached())?.preferredLanguage ?? 'en';
      final firstSync = (await ref.read(databaseProvider).getValue('feed_synced_at')) == null;
      final fresh = await ref.read(feedRepoProvider).refresh(lang: lang);
      ref.read(offlineProvider.notifier).set(false);
      if (firstSync) return; // don't toast the whole backlog on the first sync
      final docs = fresh.where((f) => f.kind != 'cert_expiry').toList();
      for (final f in docs.take(5)) {
        final critical = f.priority == 'critical';
        await notifier.show(
          id: f.alertId.hashCode,
          title: critical ? 'URGENT: safety advisory' : _kindTitle(f.kind),
          body: _titleOf(f),
          payload: f.documentId == null ? null : '/document/${f.documentId}',
        );
      }
      if (docs.length > 5) {
        await notifier.show(id: 1, title: '${docs.length - 5} more new alerts', body: 'Open the app to see them.');
      }
    } on ApiException catch (e) {
      if (e.offline) ref.read(offlineProvider.notifier).set(true);
      if (e.unauthorized) ref.read(sessionProvider.notifier).signedOut();
    }
  }

  Future<void> _syncCertificates() async {
    try {
      await ref.read(certRepoProvider).sync();
    } on ApiException catch (_) {
      // offline or server problem: local changes stay queued (dirty) and are pushed next time
    }
  }

  /// Toasts each reminder bucket (180/90/30/7/0 days, expired) once per certificate and expiry date.
  Future<void> showDueReminders() async {
    final db = ref.read(databaseProvider);
    final today = todayIst();
    final certs = await (db.select(db.certificates)..where((t) => t.deletedAt.isNull() & t.expiryDate.isNotNull())).get();
    for (final c in certs) {
      final expiry = parseDay(c.expiryDate);
      if (expiry == null) continue;
      final bucket = dueBucket(expiry, today);
      if (bucket == null) continue;
      final inserted = await db.into(db.reminderLog).insert(
            ReminderLogCompanion.insert(
                certificateId: c.id, expiryDate: c.expiryDate!, bucket: bucket, shownAt: DateTime.now()),
            mode: InsertMode.insertOrIgnore,
          );
      if (inserted == 0) continue; // already shown
      final label = c.subtype?.isNotEmpty == true ? '${c.type.toUpperCase()} ${c.subtype}' : c.type.toUpperCase();
      await ref.read(toastProvider).show(
            id: '${c.id}$bucket'.hashCode,
            title: bucket == expiredBucket ? '$label has expired' : '$label expires soon',
            body: describeExpiry(c.expiryDate, today),
            payload: '/wallet/${c.id}',
          );
    }
  }

  static String _kindTitle(String kind) => switch (kind) {
        'cert_impact' => 'May affect your certificate',
        'exam' => 'Exam notice',
        'updated_document' => 'Updated circular',
        _ => 'New for you',
      };

  static String _titleOf(FeedItem f) {
    if (f.documentJson != null) {
      try {
        return (jsonDecode(f.documentJson!) as Map<String, dynamic>)['title'] as String;
      } catch (_) {}
    }
    return f.reason ?? '';
  }
}

final backgroundSyncProvider = Provider<BackgroundSync>((ref) {
  final s = BackgroundSync(ref);
  ref.onDispose(s.stop);
  return s;
});
