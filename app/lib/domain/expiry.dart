/// Certificate expiry logic. Mirrors backend/sa_backend/services/reminders.py so the app and server agree.
library;

const reminderOffsetsDays = [180, 90, 30, 7, 0];
const expiredBucket = -1;

enum ExpiryStatus { expired, expiringSoon, valid, noExpiry }

/// Today's date in India (IST, UTC+05:30, no daylight saving), whatever the device timezone.
DateTime todayIst([DateTime? nowUtc]) {
  final ist = (nowUtc ?? DateTime.now().toUtc()).add(const Duration(hours: 5, minutes: 30));
  return DateTime.utc(ist.year, ist.month, ist.day);
}

/// Parses 'YYYY-MM-DD' to a UTC midnight date (no timezone shift).
DateTime? parseDay(String? s) {
  if (s == null || s.isEmpty) return null;
  final d = DateTime.tryParse(s);
  return d == null ? null : DateTime.utc(d.year, d.month, d.day);
}

String formatDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int daysLeft(DateTime expiry, DateTime today) => expiry.difference(today).inDays;

/// The most urgent reminder bucket that applies today, or null (more than 180 days left).
int? dueBucket(DateTime expiry, DateTime today) {
  final left = daysLeft(expiry, today);
  if (left < 0) return expiredBucket;
  final due = reminderOffsetsDays.where((o) => left <= o);
  return due.isEmpty ? null : due.reduce((a, b) => a < b ? a : b);
}

ExpiryStatus statusOf(String? expiryDate, DateTime today, {int soonDays = 90}) {
  final e = parseDay(expiryDate);
  if (e == null) return ExpiryStatus.noExpiry;
  final left = daysLeft(e, today);
  if (left < 0) return ExpiryStatus.expired;
  if (left <= soonDays) return ExpiryStatus.expiringSoon;
  return ExpiryStatus.valid;
}

String describeExpiry(String? expiryDate, DateTime today) {
  final e = parseDay(expiryDate);
  if (e == null) return 'No expiry';
  final left = daysLeft(e, today);
  if (left < 0) return 'Expired ${-left} day${left == -1 ? '' : 's'} ago';
  if (left == 0) return 'Expires today';
  return '$left day${left == 1 ? '' : 's'} left';
}
