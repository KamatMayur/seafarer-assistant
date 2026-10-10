import 'package:flutter_test/flutter_test.dart';
import 'package:seafarer_assistant/domain/expiry.dart';
import 'package:seafarer_assistant/domain/feed_grouping.dart';

void main() {
  group('expiry buckets (same table as backend test_reminders_quiet_hours.py)', () {
    final today = DateTime.utc(2026, 10, 6);
    final cases = <(DateTime, DateTime, int?)>[
      (DateTime.utc(2027, 6, 1), today, null),
      (DateTime.utc(2027, 4, 4), today, 180),
      (DateTime.utc(2026, 12, 1), today, 90),
      (DateTime.utc(2026, 10, 26), today, 30),
      (DateTime.utc(2026, 10, 13), today, 7),
      (DateTime.utc(2026, 10, 6), today, 0),
      (DateTime.utc(2026, 10, 5), today, expiredBucket),
      (DateTime.utc(2028, 2, 29), DateTime.utc(2028, 2, 22), 7), // leap day
      (DateTime.utc(2028, 3, 1), DateTime.utc(2028, 2, 1), 30), // across a leap February
    ];
    for (final (expiry, day, bucket) in cases) {
      test('$expiry on $day -> $bucket', () => expect(dueBucket(expiry, day), bucket));
    }
  });

  test('todayIst uses India time whatever the device timezone', () {
    // 20:00 UTC on 5 Oct is 01:30 on 6 Oct in India.
    expect(todayIst(DateTime.utc(2026, 10, 5, 20)), DateTime.utc(2026, 10, 6));
    expect(todayIst(DateTime.utc(2026, 10, 5, 18, 29)), DateTime.utc(2026, 10, 5));
  });

  test('dates round-trip without timezone shift', () {
    expect(formatDay(parseDay('2028-02-29')!), '2028-02-29');
    expect(parseDay(''), isNull);
    expect(parseDay(null), isNull);
  });

  test('status and description', () {
    final today = DateTime.utc(2026, 10, 6);
    expect(statusOf(null, today), ExpiryStatus.noExpiry);
    expect(statusOf('2026-10-01', today), ExpiryStatus.expired);
    expect(statusOf('2026-12-01', today), ExpiryStatus.expiringSoon);
    expect(statusOf('2028-01-01', today), ExpiryStatus.valid);
    expect(describeExpiry('2026-10-05', today), 'Expired 1 day ago');
    expect(describeExpiry('2026-10-06', today), 'Expires today');
    expect(describeExpiry('2026-10-07', today), '1 day left');
    expect(describeExpiry(null, today), 'No expiry');
  });

  group('feed grouping (decisions.md R10)', () {
    FeedAlert a(String id, String kind, {String? doc, int minutesAgo = 0, String priority = 'normal', bool read = false}) =>
        FeedAlert(
          alertId: id,
          kind: kind,
          priority: priority,
          createdAt: DateTime(2026, 10, 9, 12).subtract(Duration(minutes: minutesAgo)),
          read: read,
          documentId: doc,
        );

    test('document alert and its certificate impact become one card', () {
      final cards = groupFeed([a('1', 'new_document', doc: 'D1'), a('2', 'cert_impact', doc: 'D1')]);
      expect(cards, hasLength(1));
      expect(cards.single.main.alertId, '1');
      expect(cards.single.affectsCertificate, isTrue);
      expect(cards.single.all.map((x) => x.alertId), containsAll(['1', '2']));
    });

    test('an update keeps the earlier alert on the same card', () {
      final cards = groupFeed([a('new', 'new_document', doc: 'D1', minutesAgo: 60, read: true), a('upd', 'updated_document', doc: 'D1')]);
      expect(cards, hasLength(1));
      expect(cards.single.isUpdate, isTrue);
      expect(cards.single.earlier.single.alertId, 'new');
    });

    test('unread critical advisories are pinned first; reminders stand alone', () {
      final cards = groupFeed([
        a('n', 'new_document', doc: 'D1'),
        a('c', 'new_document', doc: 'D2', priority: 'critical', minutesAgo: 300),
        a('r', 'cert_expiry', minutesAgo: 10),
      ]);
      expect(cards.map((c) => c.main.alertId), ['c', 'n', 'r']);
    });

    test('a read critical advisory is not pinned', () {
      final cards = groupFeed([
        a('n', 'new_document', doc: 'D1'),
        a('c', 'new_document', doc: 'D2', priority: 'critical', minutesAgo: 300, read: true),
      ]);
      expect(cards.first.main.alertId, 'n');
    });
  });
}
