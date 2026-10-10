import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../domain/feed_grouping.dart';
import 'db.dart';
import 'models.dart';

const _uuid = Uuid();

// ------------------------------------------------------------------------------------------- auth
class AuthRepository {
  AuthRepository(this.api, this.db);
  final ApiClient api;
  final AppDatabase db;

  Future<bool> isSignedIn() async => await api.tokens.refreshToken() != null;

  Future<void> startEmailLogin(String email) => api.post('/v1/auth/email/start', body: {'email': email}, auth: false);

  /// Returns true for a new account.
  Future<bool> verify(String email, String code, {required bool consentCore, required bool consentEmail}) async {
    final j = await api.post('/v1/auth/verify', auth: false, body: {
      'identifier': email,
      'code': code,
      'consents': [
        {'purpose': 'core_service', 'granted': consentCore, 'policy_version': AppConfig.privacyPolicyVersion},
        {'purpose': 'email_alerts', 'granted': consentEmail, 'policy_version': AppConfig.privacyPolicyVersion},
      ],
    }) as Map<String, dynamic>;
    await api.tokens.save(j['access_token'] as String, j['refresh_token'] as String);
    return j['new_user'] as bool? ?? false;
  }

  Future<void> registerDevice(String appVersion) =>
      api.post('/v1/me/devices', body: {'platform': 'windows', 'app_version': appVersion});

  Future<void> signOut() async {
    await api.tokens.clear();
    await db.wipeUserData();
  }

  /// DPDP: delete the account on the server, then everything on this device.
  Future<void> deleteAccount() async {
    await api.delete('/v1/me');
    await signOut();
  }

  Future<List<int>> exportData() => api.getBytes('/v1/me/export');
}

// ------------------------------------------------------------------------------------------- profile + meta
class ProfileRepository {
  ProfileRepository(this.api, this.db);
  final ApiClient api;
  final AppDatabase db;

  Future<Profile?> cached() async {
    final raw = await db.getValue('profile');
    return raw == null ? null : Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<Profile> fetch() async {
    final j = await api.get('/v1/me') as Map<String, dynamic>;
    await db.setValue('profile', jsonEncode(j));
    return Profile.fromJson(j);
  }

  /// Online first; falls back to the cached copy when offline.
  Future<Profile?> load() async {
    try {
      return await fetch();
    } on ApiException catch (e) {
      if (e.offline) return cached();
      rethrow;
    }
  }

  Future<Profile> update(Profile p) async {
    final j = await api.patch('/v1/me', body: p.toPatch()) as Map<String, dynamic>;
    await db.setValue('profile', jsonEncode(j));
    return Profile.fromJson(j);
  }

  Future<Map<String, String>> topics() async {
    final list = await api.get('/v1/me/topics') as List;
    return {for (final t in list) t['topic'] as String: t['mode'] as String};
  }

  Future<void> saveTopics(Map<String, String> modes) =>
      api.put('/v1/me/topics', body: [for (final e in modes.entries) {'topic': e.key, 'mode': e.value}]);

  Future<Meta> meta() async {
    try {
      final j = await api.get('/v1/meta', auth: false) as Map<String, dynamic>;
      await db.setValue('meta', jsonEncode(j));
      return Meta.fromJson(j);
    } on ApiException catch (e) {
      final raw = await db.getValue('meta');
      if (e.offline && raw != null) return Meta.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      rethrow;
    }
  }
}

// ------------------------------------------------------------------------------------------- feed
class FeedRepository {
  FeedRepository(this.api, this.db);
  final ApiClient api;
  final AppDatabase db;

  Stream<List<FeedItem>> watch() =>
      (db.select(db.feedItems)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  static FeedAlert toAlert(FeedItem f) => FeedAlert(
        alertId: f.alertId,
        kind: f.kind,
        priority: f.priority,
        createdAt: f.createdAt,
        read: f.read,
        reason: f.reason,
        documentId: f.documentId,
        certificateId: f.certificateId,
      );

  /// Pulls alerts newer than the newest one stored (all of the first page on first run).
  /// Returns the alerts that were not on this device before, for toasts.
  Future<List<FeedItem>> refresh({String lang = 'en'}) async {
    await _pushReadMarks();
    final newest = await (db.selectOnly(db.feedItems)..addColumns([db.feedItems.createdAt.max()]))
        .map((r) => r.read(db.feedItems.createdAt.max()))
        .getSingleOrNull();
    final fresh = <FeedItem>[];
    String? before;
    // At most 5 pages (150 alerts) per refresh; enough after weeks offline, small on slow links.
    for (var page = 0; page < 5; page++) {
      final j = await api.get('/v1/feed', query: {
        'after': newest?.toUtc().toIso8601String(),
        'before': before,
        'limit': 30,
        'lang': lang,
      }) as Map<String, dynamic>;
      final items = (j['items'] as List).cast<Map<String, dynamic>>();
      await db.batch((b) {
        for (final it in items) {
          final row = FeedItemsCompanion.insert(
            alertId: it['alert_id'] as String,
            kind: it['kind'] as String,
            priority: it['priority'] as String,
            createdAt: DateTime.parse(it['created_at'] as String),
            read: Value(it['read'] as bool? ?? false),
            reason: Value(it['reason'] as String?),
            documentId: Value((it['document'] as Map?)?['id'] as String?),
            certificateId: Value(it['certificate_id'] as String?),
            documentJson: Value(it['document'] == null ? null : jsonEncode(it['document'])),
          );
          b.insert(db.feedItems, row, mode: InsertMode.insertOrIgnore);
          if (it['document'] != null) {
            final d = DocumentCard.fromJson(it['document'] as Map<String, dynamic>);
            b.insert(
              db.cachedDocuments,
              CachedDocumentsCompanion.insert(
                id: d.id,
                title: d.title,
                circularNumber: Value(d.circularNumber),
                publishedDate: Value(d.publishedDate?.toIso8601String().substring(0, 10)),
                docType: d.docType,
                priority: d.priority,
                summaryShort: Value(d.summaryShort),
                cachedAt: DateTime.now(),
              ),
              onConflict: DoUpdate((_) => CachedDocumentsCompanion(
                    title: Value(d.title),
                    summaryShort: Value(d.summaryShort),
                    priority: Value(d.priority),
                  )),
            );
          }
        }
      });
      for (final it in items) {
        if (!(it['read'] as bool? ?? false)) {
          final row = await (db.select(db.feedItems)..where((t) => t.alertId.equals(it['alert_id'] as String)))
              .getSingle();
          fresh.add(row);
        }
      }
      before = j['next_before'] as String?;
      if (before == null) break;
    }
    await db.setValue('feed_synced_at', DateTime.now().toIso8601String());
    return fresh;
  }

  Future<void> markRead(Iterable<String> alertIds) async {
    final ids = alertIds.toList();
    await (db.update(db.feedItems)..where((t) => t.alertId.isIn(ids) & t.read.equals(false)))
        .write(const FeedItemsCompanion(read: Value(true), readDirty: Value(true)));
    try {
      await _pushReadMarks();
    } on ApiException catch (e) {
      if (!e.offline) rethrow; // sent on the next refresh
    }
  }

  Future<void> _pushReadMarks() async {
    final dirty = await (db.select(db.feedItems)..where((t) => t.readDirty.equals(true))).get();
    for (final f in dirty) {
      try {
        await api.post('/v1/feed/${f.alertId}/read');
      } on ApiException catch (e) {
        if (e.status != 404) rethrow; // 404: alert deleted on the server, drop the mark
      }
      await (db.update(db.feedItems)..where((t) => t.alertId.equals(f.alertId)))
          .write(const FeedItemsCompanion(readDirty: Value(false)));
    }
  }
}

// ------------------------------------------------------------------------------------------- documents
class DocumentRepository {
  DocumentRepository(this.api, this.db);
  final ApiClient api;
  final AppDatabase db;

  /// Online first (and cached); the cached copy when offline. [fromCache] tells the UI to show a banner.
  Future<({DocumentDetail detail, bool fromCache})> detail(String id, {String lang = 'en'}) async {
    try {
      final j = await api.get('/v1/documents/$id', query: {'lang': lang}) as Map<String, dynamic>;
      final d = DocumentDetail.fromJson(j);
      await db.into(db.cachedDocuments).insertOnConflictUpdate(CachedDocumentsCompanion.insert(
            id: id,
            title: d.card.title,
            circularNumber: Value(d.card.circularNumber),
            publishedDate: Value(d.card.publishedDate?.toIso8601String().substring(0, 10)),
            docType: d.card.docType,
            priority: d.card.priority,
            summaryShort: Value(d.card.summaryShort),
            detailJson: Value(jsonEncode(j)),
            cachedAt: DateTime.now(),
          ));
      return (detail: d, fromCache: false);
    } on ApiException catch (e) {
      if (!e.offline) rethrow;
      final row = await (db.select(db.cachedDocuments)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row?.detailJson == null) {
        throw ApiException('You are offline and this document has not been opened on this device before.',
            offline: true);
      }
      return (detail: DocumentDetail.fromJson(jsonDecode(row!.detailJson!) as Map<String, dynamic>), fromCache: true);
    }
  }

  /// Server search; offline it searches titles/summaries of documents already on this device.
  Future<({List<DocumentCard> items, int total, bool offline})> search({
    String? q,
    String? docType,
    String? department,
    int page = 1,
  }) async {
    try {
      final j = await api.get('/v1/documents', query: {
        'q': q,
        'doc_type': docType,
        'department': department,
        'page': page,
      }) as Map<String, dynamic>;
      final items =
          (j['items'] as List).map((e) => DocumentCard.fromJson(e as Map<String, dynamic>)).toList();
      return (items: items, total: j['total'] as int, offline: false);
    } on ApiException catch (e) {
      if (!e.offline) rethrow;
      final query = db.select(db.cachedDocuments);
      if (q != null && q.trim().isNotEmpty) {
        final like = '%${q.trim()}%';
        query.where((t) => t.title.like(like) | t.summaryShort.like(like) | t.circularNumber.like(like));
      }
      if (docType != null) query.where((t) => t.docType.equals(docType));
      query.orderBy([(t) => OrderingTerm.desc(t.publishedDate)]);
      final rows = await query.get();
      final items = rows
          .map((r) => DocumentCard(
                id: r.id,
                title: r.title,
                circularNumber: r.circularNumber,
                publishedDate: r.publishedDate == null ? null : DateTime.tryParse(r.publishedDate!),
                docType: r.docType,
                priority: r.priority,
                status: 'processed',
                summaryShort: r.summaryShort,
              ))
          .toList();
      return (items: items, total: items.length, offline: true);
    }
  }
}

// ------------------------------------------------------------------------------------------- certificates
class SyncReport {
  SyncReport(this.pushed, this.pulled, this.conflicts);
  final int pushed;
  final int pulled;
  final int conflicts;
}

/// Certificates are edited locally (works offline) and synced; the server never silently overwrites a change.
class CertificateRepository {
  CertificateRepository(this.api, this.db);
  final ApiClient api;
  final AppDatabase db;

  Stream<List<Certificate>> watchAll() => (db.select(db.certificates)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.expiryDate)]))
      .watch();

  Future<Certificate?> byId(String id) =>
      (db.select(db.certificates)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<String> save({
    String? id,
    required String type,
    String? subtype,
    String? number,
    String? issuingAuthority,
    String? issueDate,
    String? expiryDate,
    String? filePath,
    String? fileName,
  }) async {
    final certId = id ?? _uuid.v4();
    final existing = id == null ? null : await byId(id);
    await db.into(db.certificates).insertOnConflictUpdate(CertificatesCompanion.insert(
          id: certId,
          type: type,
          subtype: Value(subtype),
          number: Value(number),
          issuingAuthority: Value(issuingAuthority),
          issueDate: Value(issueDate),
          expiryDate: Value(expiryDate),
          version: Value(existing?.version ?? 0),
          updatedAt: DateTime.now(),
          dirty: const Value(true),
          filePath: Value(filePath ?? existing?.filePath),
          fileName: Value(fileName ?? existing?.fileName),
        ));
    return certId;
  }

  Future<void> softDelete(String id) =>
      (db.update(db.certificates)..where((t) => t.id.equals(id))).write(CertificatesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        dirty: const Value(true),
      ));

  Map<String, dynamic> _toJson(Certificate c) => {
        'id': c.id,
        'type': c.type,
        'subtype': c.subtype,
        'number': c.number,
        'issuing_authority': c.issuingAuthority,
        'issue_date': c.issueDate,
        'expiry_date': c.expiryDate,
        'version': c.version,
        'deleted_at': c.deletedAt?.toUtc().toIso8601String(),
      };

  /// Keep the server copy (discarding the local edit) or keep mine (re-push on top of the server version).
  Future<void> resolveConflict(String id, {required bool keepMine}) async {
    final c = await byId(id);
    if (c?.conflictJson == null) return;
    final server = jsonDecode(c!.conflictJson!) as Map<String, dynamic>;
    final serverVersion = server['version'] as int? ?? c.version;
    if (keepMine) {
      await (db.update(db.certificates)..where((t) => t.id.equals(id))).write(CertificatesCompanion(
        version: Value(serverVersion),
        conflictJson: const Value(null),
        dirty: const Value(true),
      ));
    } else {
      await _applyServer(server, version: serverVersion);
    }
  }

  Future<void> _applyServer(Map<String, dynamic> s, {int? version}) async {
    final id = s['id'] as String;
    final existing = await byId(id);
    await db.into(db.certificates).insertOnConflictUpdate(CertificatesCompanion.insert(
          id: id,
          type: s['type'] as String,
          subtype: Value(s['subtype'] as String?),
          number: Value(s['number'] as String?),
          issuingAuthority: Value(s['issuing_authority'] as String?),
          issueDate: Value(s['issue_date'] as String?),
          expiryDate: Value(s['expiry_date'] as String?),
          version: Value(version ?? s['version'] as int? ?? 0),
          updatedAt: DateTime.tryParse('${s['updated_at']}') ?? DateTime.now(),
          deletedAt: Value(s['deleted_at'] == null ? null : DateTime.tryParse('${s['deleted_at']}')),
          dirty: const Value(false),
          conflictJson: const Value(null),
          filePath: Value(existing?.filePath), // files never come from the server
          fileName: Value(existing?.fileName),
        ));
  }

  /// Push local changes, then pull server changes. Safe to call often; works in both directions.
  Future<SyncReport> sync() async {
    final dirty = await (db.select(db.certificates)
          ..where((t) => t.dirty.equals(true) & t.conflictJson.isNull()))
        .get();
    var pushed = 0, conflicts = 0, pulled = 0;
    if (dirty.isNotEmpty) {
      final r = await api.post('/v1/sync/push', body: {'certificates': dirty.map(_toJson).toList()})
          as Map<String, dynamic>;
      final applied = (r['applied'] as Map<String, dynamic>).cast<String, int>();
      for (final e in applied.entries) {
        await (db.update(db.certificates)..where((t) => t.id.equals(e.key)))
            .write(CertificatesCompanion(version: Value(e.value), dirty: const Value(false)));
        pushed++;
      }
      for (final c in (r['conflicts'] as List).cast<Map<String, dynamic>>()) {
        if (c['entity'] != 'certificate') continue;
        await (db.update(db.certificates)..where((t) => t.id.equals(c['id'] as String)))
            .write(CertificatesCompanion(conflictJson: Value(jsonEncode(c['server']))));
        conflicts++;
      }
    }
    final since = await db.getValue('cert_cursor');
    final changes = await api.get('/v1/sync/changes', query: {'since': since}) as Map<String, dynamic>;
    for (final s in (changes['certificates'] as List).cast<Map<String, dynamic>>()) {
      final local = await byId(s['id'] as String);
      if (local != null && local.dirty) {
        // Already marked by the push above: don't count it twice.
        if (local.conflictJson == null && (s['version'] as int? ?? 0) > local.version) {
          await (db.update(db.certificates)..where((t) => t.id.equals(local.id)))
              .write(CertificatesCompanion(conflictJson: Value(jsonEncode(s))));
          conflicts++;
        }
        continue; // local edit wins until pushed or resolved
      }
      await _applyServer(s);
      pulled++;
    }
    await db.setValue('cert_cursor', changes['cursor'] as String);
    return SyncReport(pushed, pulled, conflicts);
  }
}
