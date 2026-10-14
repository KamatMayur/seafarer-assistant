import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'db.g.dart';

/// Offline-first local store. The UI reads only from here; network calls update it.
/// Dates without a time (issue/expiry) are stored as 'YYYY-MM-DD' text so they never shift across timezones.

class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class FeedItems extends Table {
  TextColumn get alertId => text()();
  TextColumn get kind => text()();
  TextColumn get priority => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get read => boolean().withDefault(const Constant(false))();
  BoolColumn get readDirty => boolean().withDefault(const Constant(false))(); // read offline, not yet sent
  TextColumn get reason => text().nullable()();
  TextColumn get documentId => text().nullable()();
  TextColumn get certificateId => text().nullable()();
  TextColumn get documentJson => text().nullable()(); // DocumentCard as JSON

  @override
  Set<Column> get primaryKey => {alertId};
}

class CachedDocuments extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get circularNumber => text().nullable()();
  TextColumn get publishedDate => text().nullable()();
  TextColumn get docType => text()();
  TextColumn get priority => text()();
  TextColumn get summaryShort => text().nullable()();
  TextColumn get detailJson => text().nullable()(); // full DocumentDetail once opened
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Certificates extends Table {
  TextColumn get id => text()(); // UUID generated on the device
  TextColumn get type => text()();
  TextColumn get subtype => text().nullable()();
  TextColumn get number => text().nullable()();
  TextColumn get issuingAuthority => text().nullable()();
  TextColumn get issueDate => text().nullable()();
  TextColumn get expiryDate => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(0))(); // last server version seen
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))(); // changed locally, not yet pushed
  TextColumn get filePath => text().nullable()(); // AES-256-GCM encrypted copy, device only
  TextColumn get fileName => text().nullable()();
  TextColumn get conflictJson => text().nullable()(); // server copy when a sync conflict happened

  @override
  Set<Column> get primaryKey => {id};
}

/// Sea service (S15). Same offline-first sync rules as certificates. Dates are 'YYYY-MM-DD' text.
class SeaServices extends Table {
  TextColumn get id => text()(); // UUID generated on the device
  TextColumn get vesselName => text()();
  TextColumn get imo => text().nullable()();
  TextColumn get rank => text().nullable()();
  TextColumn get signOn => text()();
  TextColumn get signOff => text().nullable()(); // null = still on board
  TextColumn get shipType => text().nullable()();
  TextColumn get flag => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(0))(); // last server version seen
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))(); // changed locally, not yet pushed
  TextColumn get conflictJson => text().nullable()(); // server copy when a sync conflict happened

  @override
  Set<Column> get primaryKey => {id};
}

/// Expiry reminders already shown as a Windows toast, so each one appears once.
class ReminderLog extends Table {
  TextColumn get certificateId => text()();
  TextColumn get expiryDate => text()();
  IntColumn get bucket => integer()();
  DateTimeColumn get shownAt => dateTime()();

  @override
  Set<Column> get primaryKey => {certificateId, expiryDate, bucket};
}

@DriftDatabase(tables: [KeyValues, FeedItems, CachedDocuments, Certificates, ReminderLog, SeaServices])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'seafarer_assistant'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(seaServices); // v2: sea service log
        },
      );

  // ---- key/value ----
  Future<String?> getValue(String key) async =>
      (await (select(keyValues)..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setValue(String key, String value) =>
      into(keyValues).insertOnConflictUpdate(KeyValuesCompanion.insert(key: key, value: value));

  Future<void> removeValue(String key) => (delete(keyValues)..where((t) => t.key.equals(key))).go();

  Stream<String?> watchValue(String key) =>
      (select(keyValues)..where((t) => t.key.equals(key))).watchSingleOrNull().map((r) => r?.value);

  /// Sign-out / account deletion: remove everything that belongs to the user.
  Future<void> wipeUserData() => transaction(() async {
        await delete(feedItems).go();
        await delete(certificates).go();
        await delete(seaServices).go();
        await delete(reminderLog).go();
        await (delete(keyValues)..where((t) => t.key.isNotIn(['api_base', 'data_saver']))).go();
      });
}
