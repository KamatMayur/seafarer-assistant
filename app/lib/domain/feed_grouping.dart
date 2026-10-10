/// Groups feed alerts into cards. A document's 'new_document'/'exam'/'updated_document' alert and its
/// 'cert_impact' alerts become one card (decisions.md R10), so a CoC holder does not see the same circular twice.
library;

class FeedAlert {
  const FeedAlert({
    required this.alertId,
    required this.kind,
    required this.priority,
    required this.createdAt,
    required this.read,
    this.reason,
    this.documentId,
    this.certificateId,
  });

  final String alertId;
  final String kind;
  final String priority;
  final DateTime createdAt;
  final bool read;
  final String? reason;
  final String? documentId;
  final String? certificateId;
}

class FeedCard {
  FeedCard(this.main, this.impacts, [this.earlier = const []]);

  /// The alert that represents the card (the document alert if there is one).
  final FeedAlert main;

  /// 'cert_impact' alerts for the same document.
  final List<FeedAlert> impacts;

  /// Older alerts for the same document (e.g. the original 'new_document' before an 'updated_document').
  final List<FeedAlert> earlier;

  List<FeedAlert> get all => [main, ...impacts, ...earlier];
  bool get unread => all.any((a) => !a.read);
  bool get affectsCertificate => impacts.isNotEmpty || main.kind == 'cert_impact';
  bool get isCritical => main.priority == 'critical';
  bool get isUpdate => main.kind == 'updated_document';
  DateTime get newest => all.map((a) => a.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
}

List<FeedCard> groupFeed(List<FeedAlert> alerts) {
  final byDoc = <String, List<FeedAlert>>{};
  final cards = <FeedCard>[];
  for (final a in alerts) {
    if (a.documentId == null) {
      cards.add(FeedCard(a, const [])); // expiry reminders, broadcasts
    } else {
      byDoc.putIfAbsent(a.documentId!, () => []).add(a);
    }
  }
  for (final group in byDoc.values) {
    final docAlerts = group.where((a) => a.kind != 'cert_impact').toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final impacts = group.where((a) => a.kind == 'cert_impact').toList();
    if (docAlerts.isEmpty) {
      cards.add(FeedCard(impacts.first, impacts.skip(1).toList()));
    } else {
      cards.add(FeedCard(docAlerts.first, impacts, docAlerts.skip(1).toList()));
    }
  }
  // Unread critical first, then newest.
  cards.sort((a, b) {
    final ca = a.isCritical && a.unread, cb = b.isCritical && b.unread;
    if (ca != cb) return ca ? -1 : 1;
    return b.newest.compareTo(a.newest);
  });
  return cards;
}
