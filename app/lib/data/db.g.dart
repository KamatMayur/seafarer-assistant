// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $KeyValuesTable extends KeyValues
    with TableInfo<$KeyValuesTable, KeyValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KeyValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'key_values';
  @override
  VerificationContext validateIntegrity(
    Insertable<KeyValue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KeyValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KeyValue(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $KeyValuesTable createAlias(String alias) {
    return $KeyValuesTable(attachedDatabase, alias);
  }
}

class KeyValue extends DataClass implements Insertable<KeyValue> {
  final String key;
  final String value;
  const KeyValue({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  KeyValuesCompanion toCompanion(bool nullToAbsent) {
    return KeyValuesCompanion(key: Value(key), value: Value(value));
  }

  factory KeyValue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KeyValue(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  KeyValue copyWith({String? key, String? value}) =>
      KeyValue(key: key ?? this.key, value: value ?? this.value);
  KeyValue copyWithCompanion(KeyValuesCompanion data) {
    return KeyValue(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KeyValue(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KeyValue && other.key == this.key && other.value == this.value);
}

class KeyValuesCompanion extends UpdateCompanion<KeyValue> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const KeyValuesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KeyValuesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<KeyValue> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KeyValuesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return KeyValuesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KeyValuesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FeedItemsTable extends FeedItems
    with TableInfo<$FeedItemsTable, FeedItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeedItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _alertIdMeta = const VerificationMeta(
    'alertId',
  );
  @override
  late final GeneratedColumn<String> alertId = GeneratedColumn<String>(
    'alert_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readMeta = const VerificationMeta('read');
  @override
  late final GeneratedColumn<bool> read = GeneratedColumn<bool>(
    'read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _readDirtyMeta = const VerificationMeta(
    'readDirty',
  );
  @override
  late final GeneratedColumn<bool> readDirty = GeneratedColumn<bool>(
    'read_dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("read_dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _certificateIdMeta = const VerificationMeta(
    'certificateId',
  );
  @override
  late final GeneratedColumn<String> certificateId = GeneratedColumn<String>(
    'certificate_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _documentJsonMeta = const VerificationMeta(
    'documentJson',
  );
  @override
  late final GeneratedColumn<String> documentJson = GeneratedColumn<String>(
    'document_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    alertId,
    kind,
    priority,
    createdAt,
    read,
    readDirty,
    reason,
    documentId,
    certificateId,
    documentJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feed_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<FeedItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('alert_id')) {
      context.handle(
        _alertIdMeta,
        alertId.isAcceptableOrUnknown(data['alert_id']!, _alertIdMeta),
      );
    } else if (isInserting) {
      context.missing(_alertIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('read')) {
      context.handle(
        _readMeta,
        read.isAcceptableOrUnknown(data['read']!, _readMeta),
      );
    }
    if (data.containsKey('read_dirty')) {
      context.handle(
        _readDirtyMeta,
        readDirty.isAcceptableOrUnknown(data['read_dirty']!, _readDirtyMeta),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    }
    if (data.containsKey('certificate_id')) {
      context.handle(
        _certificateIdMeta,
        certificateId.isAcceptableOrUnknown(
          data['certificate_id']!,
          _certificateIdMeta,
        ),
      );
    }
    if (data.containsKey('document_json')) {
      context.handle(
        _documentJsonMeta,
        documentJson.isAcceptableOrUnknown(
          data['document_json']!,
          _documentJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {alertId};
  @override
  FeedItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FeedItem(
      alertId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alert_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      read: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}read'],
      )!,
      readDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}read_dirty'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      ),
      certificateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}certificate_id'],
      ),
      documentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_json'],
      ),
    );
  }

  @override
  $FeedItemsTable createAlias(String alias) {
    return $FeedItemsTable(attachedDatabase, alias);
  }
}

class FeedItem extends DataClass implements Insertable<FeedItem> {
  final String alertId;
  final String kind;
  final String priority;
  final DateTime createdAt;
  final bool read;
  final bool readDirty;
  final String? reason;
  final String? documentId;
  final String? certificateId;
  final String? documentJson;
  const FeedItem({
    required this.alertId,
    required this.kind,
    required this.priority,
    required this.createdAt,
    required this.read,
    required this.readDirty,
    this.reason,
    this.documentId,
    this.certificateId,
    this.documentJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['alert_id'] = Variable<String>(alertId);
    map['kind'] = Variable<String>(kind);
    map['priority'] = Variable<String>(priority);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['read'] = Variable<bool>(read);
    map['read_dirty'] = Variable<bool>(readDirty);
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    if (!nullToAbsent || documentId != null) {
      map['document_id'] = Variable<String>(documentId);
    }
    if (!nullToAbsent || certificateId != null) {
      map['certificate_id'] = Variable<String>(certificateId);
    }
    if (!nullToAbsent || documentJson != null) {
      map['document_json'] = Variable<String>(documentJson);
    }
    return map;
  }

  FeedItemsCompanion toCompanion(bool nullToAbsent) {
    return FeedItemsCompanion(
      alertId: Value(alertId),
      kind: Value(kind),
      priority: Value(priority),
      createdAt: Value(createdAt),
      read: Value(read),
      readDirty: Value(readDirty),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      documentId: documentId == null && nullToAbsent
          ? const Value.absent()
          : Value(documentId),
      certificateId: certificateId == null && nullToAbsent
          ? const Value.absent()
          : Value(certificateId),
      documentJson: documentJson == null && nullToAbsent
          ? const Value.absent()
          : Value(documentJson),
    );
  }

  factory FeedItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FeedItem(
      alertId: serializer.fromJson<String>(json['alertId']),
      kind: serializer.fromJson<String>(json['kind']),
      priority: serializer.fromJson<String>(json['priority']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      read: serializer.fromJson<bool>(json['read']),
      readDirty: serializer.fromJson<bool>(json['readDirty']),
      reason: serializer.fromJson<String?>(json['reason']),
      documentId: serializer.fromJson<String?>(json['documentId']),
      certificateId: serializer.fromJson<String?>(json['certificateId']),
      documentJson: serializer.fromJson<String?>(json['documentJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'alertId': serializer.toJson<String>(alertId),
      'kind': serializer.toJson<String>(kind),
      'priority': serializer.toJson<String>(priority),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'read': serializer.toJson<bool>(read),
      'readDirty': serializer.toJson<bool>(readDirty),
      'reason': serializer.toJson<String?>(reason),
      'documentId': serializer.toJson<String?>(documentId),
      'certificateId': serializer.toJson<String?>(certificateId),
      'documentJson': serializer.toJson<String?>(documentJson),
    };
  }

  FeedItem copyWith({
    String? alertId,
    String? kind,
    String? priority,
    DateTime? createdAt,
    bool? read,
    bool? readDirty,
    Value<String?> reason = const Value.absent(),
    Value<String?> documentId = const Value.absent(),
    Value<String?> certificateId = const Value.absent(),
    Value<String?> documentJson = const Value.absent(),
  }) => FeedItem(
    alertId: alertId ?? this.alertId,
    kind: kind ?? this.kind,
    priority: priority ?? this.priority,
    createdAt: createdAt ?? this.createdAt,
    read: read ?? this.read,
    readDirty: readDirty ?? this.readDirty,
    reason: reason.present ? reason.value : this.reason,
    documentId: documentId.present ? documentId.value : this.documentId,
    certificateId: certificateId.present
        ? certificateId.value
        : this.certificateId,
    documentJson: documentJson.present ? documentJson.value : this.documentJson,
  );
  FeedItem copyWithCompanion(FeedItemsCompanion data) {
    return FeedItem(
      alertId: data.alertId.present ? data.alertId.value : this.alertId,
      kind: data.kind.present ? data.kind.value : this.kind,
      priority: data.priority.present ? data.priority.value : this.priority,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      read: data.read.present ? data.read.value : this.read,
      readDirty: data.readDirty.present ? data.readDirty.value : this.readDirty,
      reason: data.reason.present ? data.reason.value : this.reason,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      certificateId: data.certificateId.present
          ? data.certificateId.value
          : this.certificateId,
      documentJson: data.documentJson.present
          ? data.documentJson.value
          : this.documentJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FeedItem(')
          ..write('alertId: $alertId, ')
          ..write('kind: $kind, ')
          ..write('priority: $priority, ')
          ..write('createdAt: $createdAt, ')
          ..write('read: $read, ')
          ..write('readDirty: $readDirty, ')
          ..write('reason: $reason, ')
          ..write('documentId: $documentId, ')
          ..write('certificateId: $certificateId, ')
          ..write('documentJson: $documentJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    alertId,
    kind,
    priority,
    createdAt,
    read,
    readDirty,
    reason,
    documentId,
    certificateId,
    documentJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeedItem &&
          other.alertId == this.alertId &&
          other.kind == this.kind &&
          other.priority == this.priority &&
          other.createdAt == this.createdAt &&
          other.read == this.read &&
          other.readDirty == this.readDirty &&
          other.reason == this.reason &&
          other.documentId == this.documentId &&
          other.certificateId == this.certificateId &&
          other.documentJson == this.documentJson);
}

class FeedItemsCompanion extends UpdateCompanion<FeedItem> {
  final Value<String> alertId;
  final Value<String> kind;
  final Value<String> priority;
  final Value<DateTime> createdAt;
  final Value<bool> read;
  final Value<bool> readDirty;
  final Value<String?> reason;
  final Value<String?> documentId;
  final Value<String?> certificateId;
  final Value<String?> documentJson;
  final Value<int> rowid;
  const FeedItemsCompanion({
    this.alertId = const Value.absent(),
    this.kind = const Value.absent(),
    this.priority = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.read = const Value.absent(),
    this.readDirty = const Value.absent(),
    this.reason = const Value.absent(),
    this.documentId = const Value.absent(),
    this.certificateId = const Value.absent(),
    this.documentJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FeedItemsCompanion.insert({
    required String alertId,
    required String kind,
    required String priority,
    required DateTime createdAt,
    this.read = const Value.absent(),
    this.readDirty = const Value.absent(),
    this.reason = const Value.absent(),
    this.documentId = const Value.absent(),
    this.certificateId = const Value.absent(),
    this.documentJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : alertId = Value(alertId),
       kind = Value(kind),
       priority = Value(priority),
       createdAt = Value(createdAt);
  static Insertable<FeedItem> custom({
    Expression<String>? alertId,
    Expression<String>? kind,
    Expression<String>? priority,
    Expression<DateTime>? createdAt,
    Expression<bool>? read,
    Expression<bool>? readDirty,
    Expression<String>? reason,
    Expression<String>? documentId,
    Expression<String>? certificateId,
    Expression<String>? documentJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (alertId != null) 'alert_id': alertId,
      if (kind != null) 'kind': kind,
      if (priority != null) 'priority': priority,
      if (createdAt != null) 'created_at': createdAt,
      if (read != null) 'read': read,
      if (readDirty != null) 'read_dirty': readDirty,
      if (reason != null) 'reason': reason,
      if (documentId != null) 'document_id': documentId,
      if (certificateId != null) 'certificate_id': certificateId,
      if (documentJson != null) 'document_json': documentJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FeedItemsCompanion copyWith({
    Value<String>? alertId,
    Value<String>? kind,
    Value<String>? priority,
    Value<DateTime>? createdAt,
    Value<bool>? read,
    Value<bool>? readDirty,
    Value<String?>? reason,
    Value<String?>? documentId,
    Value<String?>? certificateId,
    Value<String?>? documentJson,
    Value<int>? rowid,
  }) {
    return FeedItemsCompanion(
      alertId: alertId ?? this.alertId,
      kind: kind ?? this.kind,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
      readDirty: readDirty ?? this.readDirty,
      reason: reason ?? this.reason,
      documentId: documentId ?? this.documentId,
      certificateId: certificateId ?? this.certificateId,
      documentJson: documentJson ?? this.documentJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (alertId.present) {
      map['alert_id'] = Variable<String>(alertId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (read.present) {
      map['read'] = Variable<bool>(read.value);
    }
    if (readDirty.present) {
      map['read_dirty'] = Variable<bool>(readDirty.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (certificateId.present) {
      map['certificate_id'] = Variable<String>(certificateId.value);
    }
    if (documentJson.present) {
      map['document_json'] = Variable<String>(documentJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FeedItemsCompanion(')
          ..write('alertId: $alertId, ')
          ..write('kind: $kind, ')
          ..write('priority: $priority, ')
          ..write('createdAt: $createdAt, ')
          ..write('read: $read, ')
          ..write('readDirty: $readDirty, ')
          ..write('reason: $reason, ')
          ..write('documentId: $documentId, ')
          ..write('certificateId: $certificateId, ')
          ..write('documentJson: $documentJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedDocumentsTable extends CachedDocuments
    with TableInfo<$CachedDocumentsTable, CachedDocument> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _circularNumberMeta = const VerificationMeta(
    'circularNumber',
  );
  @override
  late final GeneratedColumn<String> circularNumber = GeneratedColumn<String>(
    'circular_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publishedDateMeta = const VerificationMeta(
    'publishedDate',
  );
  @override
  late final GeneratedColumn<String> publishedDate = GeneratedColumn<String>(
    'published_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _docTypeMeta = const VerificationMeta(
    'docType',
  );
  @override
  late final GeneratedColumn<String> docType = GeneratedColumn<String>(
    'doc_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryShortMeta = const VerificationMeta(
    'summaryShort',
  );
  @override
  late final GeneratedColumn<String> summaryShort = GeneratedColumn<String>(
    'summary_short',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailJsonMeta = const VerificationMeta(
    'detailJson',
  );
  @override
  late final GeneratedColumn<String> detailJson = GeneratedColumn<String>(
    'detail_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    circularNumber,
    publishedDate,
    docType,
    priority,
    summaryShort,
    detailJson,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedDocument> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('circular_number')) {
      context.handle(
        _circularNumberMeta,
        circularNumber.isAcceptableOrUnknown(
          data['circular_number']!,
          _circularNumberMeta,
        ),
      );
    }
    if (data.containsKey('published_date')) {
      context.handle(
        _publishedDateMeta,
        publishedDate.isAcceptableOrUnknown(
          data['published_date']!,
          _publishedDateMeta,
        ),
      );
    }
    if (data.containsKey('doc_type')) {
      context.handle(
        _docTypeMeta,
        docType.isAcceptableOrUnknown(data['doc_type']!, _docTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_docTypeMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('summary_short')) {
      context.handle(
        _summaryShortMeta,
        summaryShort.isAcceptableOrUnknown(
          data['summary_short']!,
          _summaryShortMeta,
        ),
      );
    }
    if (data.containsKey('detail_json')) {
      context.handle(
        _detailJsonMeta,
        detailJson.isAcceptableOrUnknown(data['detail_json']!, _detailJsonMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedDocument map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedDocument(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      circularNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}circular_number'],
      ),
      publishedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}published_date'],
      ),
      docType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}doc_type'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority'],
      )!,
      summaryShort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_short'],
      ),
      detailJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail_json'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedDocumentsTable createAlias(String alias) {
    return $CachedDocumentsTable(attachedDatabase, alias);
  }
}

class CachedDocument extends DataClass implements Insertable<CachedDocument> {
  final String id;
  final String title;
  final String? circularNumber;
  final String? publishedDate;
  final String docType;
  final String priority;
  final String? summaryShort;
  final String? detailJson;
  final DateTime cachedAt;
  const CachedDocument({
    required this.id,
    required this.title,
    this.circularNumber,
    this.publishedDate,
    required this.docType,
    required this.priority,
    this.summaryShort,
    this.detailJson,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || circularNumber != null) {
      map['circular_number'] = Variable<String>(circularNumber);
    }
    if (!nullToAbsent || publishedDate != null) {
      map['published_date'] = Variable<String>(publishedDate);
    }
    map['doc_type'] = Variable<String>(docType);
    map['priority'] = Variable<String>(priority);
    if (!nullToAbsent || summaryShort != null) {
      map['summary_short'] = Variable<String>(summaryShort);
    }
    if (!nullToAbsent || detailJson != null) {
      map['detail_json'] = Variable<String>(detailJson);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedDocumentsCompanion toCompanion(bool nullToAbsent) {
    return CachedDocumentsCompanion(
      id: Value(id),
      title: Value(title),
      circularNumber: circularNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(circularNumber),
      publishedDate: publishedDate == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedDate),
      docType: Value(docType),
      priority: Value(priority),
      summaryShort: summaryShort == null && nullToAbsent
          ? const Value.absent()
          : Value(summaryShort),
      detailJson: detailJson == null && nullToAbsent
          ? const Value.absent()
          : Value(detailJson),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedDocument.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedDocument(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      circularNumber: serializer.fromJson<String?>(json['circularNumber']),
      publishedDate: serializer.fromJson<String?>(json['publishedDate']),
      docType: serializer.fromJson<String>(json['docType']),
      priority: serializer.fromJson<String>(json['priority']),
      summaryShort: serializer.fromJson<String?>(json['summaryShort']),
      detailJson: serializer.fromJson<String?>(json['detailJson']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'circularNumber': serializer.toJson<String?>(circularNumber),
      'publishedDate': serializer.toJson<String?>(publishedDate),
      'docType': serializer.toJson<String>(docType),
      'priority': serializer.toJson<String>(priority),
      'summaryShort': serializer.toJson<String?>(summaryShort),
      'detailJson': serializer.toJson<String?>(detailJson),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedDocument copyWith({
    String? id,
    String? title,
    Value<String?> circularNumber = const Value.absent(),
    Value<String?> publishedDate = const Value.absent(),
    String? docType,
    String? priority,
    Value<String?> summaryShort = const Value.absent(),
    Value<String?> detailJson = const Value.absent(),
    DateTime? cachedAt,
  }) => CachedDocument(
    id: id ?? this.id,
    title: title ?? this.title,
    circularNumber: circularNumber.present
        ? circularNumber.value
        : this.circularNumber,
    publishedDate: publishedDate.present
        ? publishedDate.value
        : this.publishedDate,
    docType: docType ?? this.docType,
    priority: priority ?? this.priority,
    summaryShort: summaryShort.present ? summaryShort.value : this.summaryShort,
    detailJson: detailJson.present ? detailJson.value : this.detailJson,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedDocument copyWithCompanion(CachedDocumentsCompanion data) {
    return CachedDocument(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      circularNumber: data.circularNumber.present
          ? data.circularNumber.value
          : this.circularNumber,
      publishedDate: data.publishedDate.present
          ? data.publishedDate.value
          : this.publishedDate,
      docType: data.docType.present ? data.docType.value : this.docType,
      priority: data.priority.present ? data.priority.value : this.priority,
      summaryShort: data.summaryShort.present
          ? data.summaryShort.value
          : this.summaryShort,
      detailJson: data.detailJson.present
          ? data.detailJson.value
          : this.detailJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedDocument(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('circularNumber: $circularNumber, ')
          ..write('publishedDate: $publishedDate, ')
          ..write('docType: $docType, ')
          ..write('priority: $priority, ')
          ..write('summaryShort: $summaryShort, ')
          ..write('detailJson: $detailJson, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    circularNumber,
    publishedDate,
    docType,
    priority,
    summaryShort,
    detailJson,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedDocument &&
          other.id == this.id &&
          other.title == this.title &&
          other.circularNumber == this.circularNumber &&
          other.publishedDate == this.publishedDate &&
          other.docType == this.docType &&
          other.priority == this.priority &&
          other.summaryShort == this.summaryShort &&
          other.detailJson == this.detailJson &&
          other.cachedAt == this.cachedAt);
}

class CachedDocumentsCompanion extends UpdateCompanion<CachedDocument> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> circularNumber;
  final Value<String?> publishedDate;
  final Value<String> docType;
  final Value<String> priority;
  final Value<String?> summaryShort;
  final Value<String?> detailJson;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedDocumentsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.circularNumber = const Value.absent(),
    this.publishedDate = const Value.absent(),
    this.docType = const Value.absent(),
    this.priority = const Value.absent(),
    this.summaryShort = const Value.absent(),
    this.detailJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedDocumentsCompanion.insert({
    required String id,
    required String title,
    this.circularNumber = const Value.absent(),
    this.publishedDate = const Value.absent(),
    required String docType,
    required String priority,
    this.summaryShort = const Value.absent(),
    this.detailJson = const Value.absent(),
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       docType = Value(docType),
       priority = Value(priority),
       cachedAt = Value(cachedAt);
  static Insertable<CachedDocument> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? circularNumber,
    Expression<String>? publishedDate,
    Expression<String>? docType,
    Expression<String>? priority,
    Expression<String>? summaryShort,
    Expression<String>? detailJson,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (circularNumber != null) 'circular_number': circularNumber,
      if (publishedDate != null) 'published_date': publishedDate,
      if (docType != null) 'doc_type': docType,
      if (priority != null) 'priority': priority,
      if (summaryShort != null) 'summary_short': summaryShort,
      if (detailJson != null) 'detail_json': detailJson,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedDocumentsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? circularNumber,
    Value<String?>? publishedDate,
    Value<String>? docType,
    Value<String>? priority,
    Value<String?>? summaryShort,
    Value<String?>? detailJson,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedDocumentsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      circularNumber: circularNumber ?? this.circularNumber,
      publishedDate: publishedDate ?? this.publishedDate,
      docType: docType ?? this.docType,
      priority: priority ?? this.priority,
      summaryShort: summaryShort ?? this.summaryShort,
      detailJson: detailJson ?? this.detailJson,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (circularNumber.present) {
      map['circular_number'] = Variable<String>(circularNumber.value);
    }
    if (publishedDate.present) {
      map['published_date'] = Variable<String>(publishedDate.value);
    }
    if (docType.present) {
      map['doc_type'] = Variable<String>(docType.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (summaryShort.present) {
      map['summary_short'] = Variable<String>(summaryShort.value);
    }
    if (detailJson.present) {
      map['detail_json'] = Variable<String>(detailJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedDocumentsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('circularNumber: $circularNumber, ')
          ..write('publishedDate: $publishedDate, ')
          ..write('docType: $docType, ')
          ..write('priority: $priority, ')
          ..write('summaryShort: $summaryShort, ')
          ..write('detailJson: $detailJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CertificatesTable extends Certificates
    with TableInfo<$CertificatesTable, Certificate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CertificatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subtypeMeta = const VerificationMeta(
    'subtype',
  );
  @override
  late final GeneratedColumn<String> subtype = GeneratedColumn<String>(
    'subtype',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<String> number = GeneratedColumn<String>(
    'number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _issuingAuthorityMeta = const VerificationMeta(
    'issuingAuthority',
  );
  @override
  late final GeneratedColumn<String> issuingAuthority = GeneratedColumn<String>(
    'issuing_authority',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _issueDateMeta = const VerificationMeta(
    'issueDate',
  );
  @override
  late final GeneratedColumn<String> issueDate = GeneratedColumn<String>(
    'issue_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expiryDateMeta = const VerificationMeta(
    'expiryDate',
  );
  @override
  late final GeneratedColumn<String> expiryDate = GeneratedColumn<String>(
    'expiry_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _conflictJsonMeta = const VerificationMeta(
    'conflictJson',
  );
  @override
  late final GeneratedColumn<String> conflictJson = GeneratedColumn<String>(
    'conflict_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    subtype,
    number,
    issuingAuthority,
    issueDate,
    expiryDate,
    version,
    updatedAt,
    deletedAt,
    dirty,
    filePath,
    fileName,
    conflictJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'certificates';
  @override
  VerificationContext validateIntegrity(
    Insertable<Certificate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('subtype')) {
      context.handle(
        _subtypeMeta,
        subtype.isAcceptableOrUnknown(data['subtype']!, _subtypeMeta),
      );
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    }
    if (data.containsKey('issuing_authority')) {
      context.handle(
        _issuingAuthorityMeta,
        issuingAuthority.isAcceptableOrUnknown(
          data['issuing_authority']!,
          _issuingAuthorityMeta,
        ),
      );
    }
    if (data.containsKey('issue_date')) {
      context.handle(
        _issueDateMeta,
        issueDate.isAcceptableOrUnknown(data['issue_date']!, _issueDateMeta),
      );
    }
    if (data.containsKey('expiry_date')) {
      context.handle(
        _expiryDateMeta,
        expiryDate.isAcceptableOrUnknown(data['expiry_date']!, _expiryDateMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    }
    if (data.containsKey('conflict_json')) {
      context.handle(
        _conflictJsonMeta,
        conflictJson.isAcceptableOrUnknown(
          data['conflict_json']!,
          _conflictJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Certificate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Certificate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      subtype: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtype'],
      ),
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}number'],
      ),
      issuingAuthority: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}issuing_authority'],
      ),
      issueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}issue_date'],
      ),
      expiryDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expiry_date'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      ),
      conflictJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflict_json'],
      ),
    );
  }

  @override
  $CertificatesTable createAlias(String alias) {
    return $CertificatesTable(attachedDatabase, alias);
  }
}

class Certificate extends DataClass implements Insertable<Certificate> {
  final String id;
  final String type;
  final String? subtype;
  final String? number;
  final String? issuingAuthority;
  final String? issueDate;
  final String? expiryDate;
  final int version;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool dirty;
  final String? filePath;
  final String? fileName;
  final String? conflictJson;
  const Certificate({
    required this.id,
    required this.type,
    this.subtype,
    this.number,
    this.issuingAuthority,
    this.issueDate,
    this.expiryDate,
    required this.version,
    required this.updatedAt,
    this.deletedAt,
    required this.dirty,
    this.filePath,
    this.fileName,
    this.conflictJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || subtype != null) {
      map['subtype'] = Variable<String>(subtype);
    }
    if (!nullToAbsent || number != null) {
      map['number'] = Variable<String>(number);
    }
    if (!nullToAbsent || issuingAuthority != null) {
      map['issuing_authority'] = Variable<String>(issuingAuthority);
    }
    if (!nullToAbsent || issueDate != null) {
      map['issue_date'] = Variable<String>(issueDate);
    }
    if (!nullToAbsent || expiryDate != null) {
      map['expiry_date'] = Variable<String>(expiryDate);
    }
    map['version'] = Variable<int>(version);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    if (!nullToAbsent || fileName != null) {
      map['file_name'] = Variable<String>(fileName);
    }
    if (!nullToAbsent || conflictJson != null) {
      map['conflict_json'] = Variable<String>(conflictJson);
    }
    return map;
  }

  CertificatesCompanion toCompanion(bool nullToAbsent) {
    return CertificatesCompanion(
      id: Value(id),
      type: Value(type),
      subtype: subtype == null && nullToAbsent
          ? const Value.absent()
          : Value(subtype),
      number: number == null && nullToAbsent
          ? const Value.absent()
          : Value(number),
      issuingAuthority: issuingAuthority == null && nullToAbsent
          ? const Value.absent()
          : Value(issuingAuthority),
      issueDate: issueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(issueDate),
      expiryDate: expiryDate == null && nullToAbsent
          ? const Value.absent()
          : Value(expiryDate),
      version: Value(version),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      dirty: Value(dirty),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      fileName: fileName == null && nullToAbsent
          ? const Value.absent()
          : Value(fileName),
      conflictJson: conflictJson == null && nullToAbsent
          ? const Value.absent()
          : Value(conflictJson),
    );
  }

  factory Certificate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Certificate(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      subtype: serializer.fromJson<String?>(json['subtype']),
      number: serializer.fromJson<String?>(json['number']),
      issuingAuthority: serializer.fromJson<String?>(json['issuingAuthority']),
      issueDate: serializer.fromJson<String?>(json['issueDate']),
      expiryDate: serializer.fromJson<String?>(json['expiryDate']),
      version: serializer.fromJson<int>(json['version']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      fileName: serializer.fromJson<String?>(json['fileName']),
      conflictJson: serializer.fromJson<String?>(json['conflictJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'subtype': serializer.toJson<String?>(subtype),
      'number': serializer.toJson<String?>(number),
      'issuingAuthority': serializer.toJson<String?>(issuingAuthority),
      'issueDate': serializer.toJson<String?>(issueDate),
      'expiryDate': serializer.toJson<String?>(expiryDate),
      'version': serializer.toJson<int>(version),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'dirty': serializer.toJson<bool>(dirty),
      'filePath': serializer.toJson<String?>(filePath),
      'fileName': serializer.toJson<String?>(fileName),
      'conflictJson': serializer.toJson<String?>(conflictJson),
    };
  }

  Certificate copyWith({
    String? id,
    String? type,
    Value<String?> subtype = const Value.absent(),
    Value<String?> number = const Value.absent(),
    Value<String?> issuingAuthority = const Value.absent(),
    Value<String?> issueDate = const Value.absent(),
    Value<String?> expiryDate = const Value.absent(),
    int? version,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? dirty,
    Value<String?> filePath = const Value.absent(),
    Value<String?> fileName = const Value.absent(),
    Value<String?> conflictJson = const Value.absent(),
  }) => Certificate(
    id: id ?? this.id,
    type: type ?? this.type,
    subtype: subtype.present ? subtype.value : this.subtype,
    number: number.present ? number.value : this.number,
    issuingAuthority: issuingAuthority.present
        ? issuingAuthority.value
        : this.issuingAuthority,
    issueDate: issueDate.present ? issueDate.value : this.issueDate,
    expiryDate: expiryDate.present ? expiryDate.value : this.expiryDate,
    version: version ?? this.version,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dirty: dirty ?? this.dirty,
    filePath: filePath.present ? filePath.value : this.filePath,
    fileName: fileName.present ? fileName.value : this.fileName,
    conflictJson: conflictJson.present ? conflictJson.value : this.conflictJson,
  );
  Certificate copyWithCompanion(CertificatesCompanion data) {
    return Certificate(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      subtype: data.subtype.present ? data.subtype.value : this.subtype,
      number: data.number.present ? data.number.value : this.number,
      issuingAuthority: data.issuingAuthority.present
          ? data.issuingAuthority.value
          : this.issuingAuthority,
      issueDate: data.issueDate.present ? data.issueDate.value : this.issueDate,
      expiryDate: data.expiryDate.present
          ? data.expiryDate.value
          : this.expiryDate,
      version: data.version.present ? data.version.value : this.version,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      conflictJson: data.conflictJson.present
          ? data.conflictJson.value
          : this.conflictJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Certificate(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('subtype: $subtype, ')
          ..write('number: $number, ')
          ..write('issuingAuthority: $issuingAuthority, ')
          ..write('issueDate: $issueDate, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('filePath: $filePath, ')
          ..write('fileName: $fileName, ')
          ..write('conflictJson: $conflictJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    subtype,
    number,
    issuingAuthority,
    issueDate,
    expiryDate,
    version,
    updatedAt,
    deletedAt,
    dirty,
    filePath,
    fileName,
    conflictJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Certificate &&
          other.id == this.id &&
          other.type == this.type &&
          other.subtype == this.subtype &&
          other.number == this.number &&
          other.issuingAuthority == this.issuingAuthority &&
          other.issueDate == this.issueDate &&
          other.expiryDate == this.expiryDate &&
          other.version == this.version &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dirty == this.dirty &&
          other.filePath == this.filePath &&
          other.fileName == this.fileName &&
          other.conflictJson == this.conflictJson);
}

class CertificatesCompanion extends UpdateCompanion<Certificate> {
  final Value<String> id;
  final Value<String> type;
  final Value<String?> subtype;
  final Value<String?> number;
  final Value<String?> issuingAuthority;
  final Value<String?> issueDate;
  final Value<String?> expiryDate;
  final Value<int> version;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<bool> dirty;
  final Value<String?> filePath;
  final Value<String?> fileName;
  final Value<String?> conflictJson;
  final Value<int> rowid;
  const CertificatesCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.subtype = const Value.absent(),
    this.number = const Value.absent(),
    this.issuingAuthority = const Value.absent(),
    this.issueDate = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileName = const Value.absent(),
    this.conflictJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CertificatesCompanion.insert({
    required String id,
    required String type,
    this.subtype = const Value.absent(),
    this.number = const Value.absent(),
    this.issuingAuthority = const Value.absent(),
    this.issueDate = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileName = const Value.absent(),
    this.conflictJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       updatedAt = Value(updatedAt);
  static Insertable<Certificate> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? subtype,
    Expression<String>? number,
    Expression<String>? issuingAuthority,
    Expression<String>? issueDate,
    Expression<String>? expiryDate,
    Expression<int>? version,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<bool>? dirty,
    Expression<String>? filePath,
    Expression<String>? fileName,
    Expression<String>? conflictJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (subtype != null) 'subtype': subtype,
      if (number != null) 'number': number,
      if (issuingAuthority != null) 'issuing_authority': issuingAuthority,
      if (issueDate != null) 'issue_date': issueDate,
      if (expiryDate != null) 'expiry_date': expiryDate,
      if (version != null) 'version': version,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dirty != null) 'dirty': dirty,
      if (filePath != null) 'file_path': filePath,
      if (fileName != null) 'file_name': fileName,
      if (conflictJson != null) 'conflict_json': conflictJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CertificatesCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String?>? subtype,
    Value<String?>? number,
    Value<String?>? issuingAuthority,
    Value<String?>? issueDate,
    Value<String?>? expiryDate,
    Value<int>? version,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<bool>? dirty,
    Value<String?>? filePath,
    Value<String?>? fileName,
    Value<String?>? conflictJson,
    Value<int>? rowid,
  }) {
    return CertificatesCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      subtype: subtype ?? this.subtype,
      number: number ?? this.number,
      issuingAuthority: issuingAuthority ?? this.issuingAuthority,
      issueDate: issueDate ?? this.issueDate,
      expiryDate: expiryDate ?? this.expiryDate,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      conflictJson: conflictJson ?? this.conflictJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (subtype.present) {
      map['subtype'] = Variable<String>(subtype.value);
    }
    if (number.present) {
      map['number'] = Variable<String>(number.value);
    }
    if (issuingAuthority.present) {
      map['issuing_authority'] = Variable<String>(issuingAuthority.value);
    }
    if (issueDate.present) {
      map['issue_date'] = Variable<String>(issueDate.value);
    }
    if (expiryDate.present) {
      map['expiry_date'] = Variable<String>(expiryDate.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (conflictJson.present) {
      map['conflict_json'] = Variable<String>(conflictJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CertificatesCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('subtype: $subtype, ')
          ..write('number: $number, ')
          ..write('issuingAuthority: $issuingAuthority, ')
          ..write('issueDate: $issueDate, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('filePath: $filePath, ')
          ..write('fileName: $fileName, ')
          ..write('conflictJson: $conflictJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReminderLogTable extends ReminderLog
    with TableInfo<$ReminderLogTable, ReminderLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReminderLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _certificateIdMeta = const VerificationMeta(
    'certificateId',
  );
  @override
  late final GeneratedColumn<String> certificateId = GeneratedColumn<String>(
    'certificate_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiryDateMeta = const VerificationMeta(
    'expiryDate',
  );
  @override
  late final GeneratedColumn<String> expiryDate = GeneratedColumn<String>(
    'expiry_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bucketMeta = const VerificationMeta('bucket');
  @override
  late final GeneratedColumn<int> bucket = GeneratedColumn<int>(
    'bucket',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shownAtMeta = const VerificationMeta(
    'shownAt',
  );
  @override
  late final GeneratedColumn<DateTime> shownAt = GeneratedColumn<DateTime>(
    'shown_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    certificateId,
    expiryDate,
    bucket,
    shownAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminder_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderLogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('certificate_id')) {
      context.handle(
        _certificateIdMeta,
        certificateId.isAcceptableOrUnknown(
          data['certificate_id']!,
          _certificateIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_certificateIdMeta);
    }
    if (data.containsKey('expiry_date')) {
      context.handle(
        _expiryDateMeta,
        expiryDate.isAcceptableOrUnknown(data['expiry_date']!, _expiryDateMeta),
      );
    } else if (isInserting) {
      context.missing(_expiryDateMeta);
    }
    if (data.containsKey('bucket')) {
      context.handle(
        _bucketMeta,
        bucket.isAcceptableOrUnknown(data['bucket']!, _bucketMeta),
      );
    } else if (isInserting) {
      context.missing(_bucketMeta);
    }
    if (data.containsKey('shown_at')) {
      context.handle(
        _shownAtMeta,
        shownAt.isAcceptableOrUnknown(data['shown_at']!, _shownAtMeta),
      );
    } else if (isInserting) {
      context.missing(_shownAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {certificateId, expiryDate, bucket};
  @override
  ReminderLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderLogData(
      certificateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}certificate_id'],
      )!,
      expiryDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expiry_date'],
      )!,
      bucket: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bucket'],
      )!,
      shownAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}shown_at'],
      )!,
    );
  }

  @override
  $ReminderLogTable createAlias(String alias) {
    return $ReminderLogTable(attachedDatabase, alias);
  }
}

class ReminderLogData extends DataClass implements Insertable<ReminderLogData> {
  final String certificateId;
  final String expiryDate;
  final int bucket;
  final DateTime shownAt;
  const ReminderLogData({
    required this.certificateId,
    required this.expiryDate,
    required this.bucket,
    required this.shownAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['certificate_id'] = Variable<String>(certificateId);
    map['expiry_date'] = Variable<String>(expiryDate);
    map['bucket'] = Variable<int>(bucket);
    map['shown_at'] = Variable<DateTime>(shownAt);
    return map;
  }

  ReminderLogCompanion toCompanion(bool nullToAbsent) {
    return ReminderLogCompanion(
      certificateId: Value(certificateId),
      expiryDate: Value(expiryDate),
      bucket: Value(bucket),
      shownAt: Value(shownAt),
    );
  }

  factory ReminderLogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderLogData(
      certificateId: serializer.fromJson<String>(json['certificateId']),
      expiryDate: serializer.fromJson<String>(json['expiryDate']),
      bucket: serializer.fromJson<int>(json['bucket']),
      shownAt: serializer.fromJson<DateTime>(json['shownAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'certificateId': serializer.toJson<String>(certificateId),
      'expiryDate': serializer.toJson<String>(expiryDate),
      'bucket': serializer.toJson<int>(bucket),
      'shownAt': serializer.toJson<DateTime>(shownAt),
    };
  }

  ReminderLogData copyWith({
    String? certificateId,
    String? expiryDate,
    int? bucket,
    DateTime? shownAt,
  }) => ReminderLogData(
    certificateId: certificateId ?? this.certificateId,
    expiryDate: expiryDate ?? this.expiryDate,
    bucket: bucket ?? this.bucket,
    shownAt: shownAt ?? this.shownAt,
  );
  ReminderLogData copyWithCompanion(ReminderLogCompanion data) {
    return ReminderLogData(
      certificateId: data.certificateId.present
          ? data.certificateId.value
          : this.certificateId,
      expiryDate: data.expiryDate.present
          ? data.expiryDate.value
          : this.expiryDate,
      bucket: data.bucket.present ? data.bucket.value : this.bucket,
      shownAt: data.shownAt.present ? data.shownAt.value : this.shownAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderLogData(')
          ..write('certificateId: $certificateId, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('bucket: $bucket, ')
          ..write('shownAt: $shownAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(certificateId, expiryDate, bucket, shownAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderLogData &&
          other.certificateId == this.certificateId &&
          other.expiryDate == this.expiryDate &&
          other.bucket == this.bucket &&
          other.shownAt == this.shownAt);
}

class ReminderLogCompanion extends UpdateCompanion<ReminderLogData> {
  final Value<String> certificateId;
  final Value<String> expiryDate;
  final Value<int> bucket;
  final Value<DateTime> shownAt;
  final Value<int> rowid;
  const ReminderLogCompanion({
    this.certificateId = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.bucket = const Value.absent(),
    this.shownAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReminderLogCompanion.insert({
    required String certificateId,
    required String expiryDate,
    required int bucket,
    required DateTime shownAt,
    this.rowid = const Value.absent(),
  }) : certificateId = Value(certificateId),
       expiryDate = Value(expiryDate),
       bucket = Value(bucket),
       shownAt = Value(shownAt);
  static Insertable<ReminderLogData> custom({
    Expression<String>? certificateId,
    Expression<String>? expiryDate,
    Expression<int>? bucket,
    Expression<DateTime>? shownAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (certificateId != null) 'certificate_id': certificateId,
      if (expiryDate != null) 'expiry_date': expiryDate,
      if (bucket != null) 'bucket': bucket,
      if (shownAt != null) 'shown_at': shownAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReminderLogCompanion copyWith({
    Value<String>? certificateId,
    Value<String>? expiryDate,
    Value<int>? bucket,
    Value<DateTime>? shownAt,
    Value<int>? rowid,
  }) {
    return ReminderLogCompanion(
      certificateId: certificateId ?? this.certificateId,
      expiryDate: expiryDate ?? this.expiryDate,
      bucket: bucket ?? this.bucket,
      shownAt: shownAt ?? this.shownAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (certificateId.present) {
      map['certificate_id'] = Variable<String>(certificateId.value);
    }
    if (expiryDate.present) {
      map['expiry_date'] = Variable<String>(expiryDate.value);
    }
    if (bucket.present) {
      map['bucket'] = Variable<int>(bucket.value);
    }
    if (shownAt.present) {
      map['shown_at'] = Variable<DateTime>(shownAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReminderLogCompanion(')
          ..write('certificateId: $certificateId, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('bucket: $bucket, ')
          ..write('shownAt: $shownAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeaServicesTable extends SeaServices
    with TableInfo<$SeaServicesTable, SeaService> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeaServicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vesselNameMeta = const VerificationMeta(
    'vesselName',
  );
  @override
  late final GeneratedColumn<String> vesselName = GeneratedColumn<String>(
    'vessel_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imoMeta = const VerificationMeta('imo');
  @override
  late final GeneratedColumn<String> imo = GeneratedColumn<String>(
    'imo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rankMeta = const VerificationMeta('rank');
  @override
  late final GeneratedColumn<String> rank = GeneratedColumn<String>(
    'rank',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _signOnMeta = const VerificationMeta('signOn');
  @override
  late final GeneratedColumn<String> signOn = GeneratedColumn<String>(
    'sign_on',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signOffMeta = const VerificationMeta(
    'signOff',
  );
  @override
  late final GeneratedColumn<String> signOff = GeneratedColumn<String>(
    'sign_off',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shipTypeMeta = const VerificationMeta(
    'shipType',
  );
  @override
  late final GeneratedColumn<String> shipType = GeneratedColumn<String>(
    'ship_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _flagMeta = const VerificationMeta('flag');
  @override
  late final GeneratedColumn<String> flag = GeneratedColumn<String>(
    'flag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _conflictJsonMeta = const VerificationMeta(
    'conflictJson',
  );
  @override
  late final GeneratedColumn<String> conflictJson = GeneratedColumn<String>(
    'conflict_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vesselName,
    imo,
    rank,
    signOn,
    signOff,
    shipType,
    flag,
    version,
    updatedAt,
    deletedAt,
    dirty,
    conflictJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sea_services';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeaService> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('vessel_name')) {
      context.handle(
        _vesselNameMeta,
        vesselName.isAcceptableOrUnknown(data['vessel_name']!, _vesselNameMeta),
      );
    } else if (isInserting) {
      context.missing(_vesselNameMeta);
    }
    if (data.containsKey('imo')) {
      context.handle(
        _imoMeta,
        imo.isAcceptableOrUnknown(data['imo']!, _imoMeta),
      );
    }
    if (data.containsKey('rank')) {
      context.handle(
        _rankMeta,
        rank.isAcceptableOrUnknown(data['rank']!, _rankMeta),
      );
    }
    if (data.containsKey('sign_on')) {
      context.handle(
        _signOnMeta,
        signOn.isAcceptableOrUnknown(data['sign_on']!, _signOnMeta),
      );
    } else if (isInserting) {
      context.missing(_signOnMeta);
    }
    if (data.containsKey('sign_off')) {
      context.handle(
        _signOffMeta,
        signOff.isAcceptableOrUnknown(data['sign_off']!, _signOffMeta),
      );
    }
    if (data.containsKey('ship_type')) {
      context.handle(
        _shipTypeMeta,
        shipType.isAcceptableOrUnknown(data['ship_type']!, _shipTypeMeta),
      );
    }
    if (data.containsKey('flag')) {
      context.handle(
        _flagMeta,
        flag.isAcceptableOrUnknown(data['flag']!, _flagMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('conflict_json')) {
      context.handle(
        _conflictJsonMeta,
        conflictJson.isAcceptableOrUnknown(
          data['conflict_json']!,
          _conflictJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SeaService map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeaService(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      vesselName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vessel_name'],
      )!,
      imo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imo'],
      ),
      rank: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rank'],
      ),
      signOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sign_on'],
      )!,
      signOff: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sign_off'],
      ),
      shipType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ship_type'],
      ),
      flag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}flag'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      conflictJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflict_json'],
      ),
    );
  }

  @override
  $SeaServicesTable createAlias(String alias) {
    return $SeaServicesTable(attachedDatabase, alias);
  }
}

class SeaService extends DataClass implements Insertable<SeaService> {
  final String id;
  final String vesselName;
  final String? imo;
  final String? rank;
  final String signOn;
  final String? signOff;
  final String? shipType;
  final String? flag;
  final int version;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool dirty;
  final String? conflictJson;
  const SeaService({
    required this.id,
    required this.vesselName,
    this.imo,
    this.rank,
    required this.signOn,
    this.signOff,
    this.shipType,
    this.flag,
    required this.version,
    required this.updatedAt,
    this.deletedAt,
    required this.dirty,
    this.conflictJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['vessel_name'] = Variable<String>(vesselName);
    if (!nullToAbsent || imo != null) {
      map['imo'] = Variable<String>(imo);
    }
    if (!nullToAbsent || rank != null) {
      map['rank'] = Variable<String>(rank);
    }
    map['sign_on'] = Variable<String>(signOn);
    if (!nullToAbsent || signOff != null) {
      map['sign_off'] = Variable<String>(signOff);
    }
    if (!nullToAbsent || shipType != null) {
      map['ship_type'] = Variable<String>(shipType);
    }
    if (!nullToAbsent || flag != null) {
      map['flag'] = Variable<String>(flag);
    }
    map['version'] = Variable<int>(version);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['dirty'] = Variable<bool>(dirty);
    if (!nullToAbsent || conflictJson != null) {
      map['conflict_json'] = Variable<String>(conflictJson);
    }
    return map;
  }

  SeaServicesCompanion toCompanion(bool nullToAbsent) {
    return SeaServicesCompanion(
      id: Value(id),
      vesselName: Value(vesselName),
      imo: imo == null && nullToAbsent ? const Value.absent() : Value(imo),
      rank: rank == null && nullToAbsent ? const Value.absent() : Value(rank),
      signOn: Value(signOn),
      signOff: signOff == null && nullToAbsent
          ? const Value.absent()
          : Value(signOff),
      shipType: shipType == null && nullToAbsent
          ? const Value.absent()
          : Value(shipType),
      flag: flag == null && nullToAbsent ? const Value.absent() : Value(flag),
      version: Value(version),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      dirty: Value(dirty),
      conflictJson: conflictJson == null && nullToAbsent
          ? const Value.absent()
          : Value(conflictJson),
    );
  }

  factory SeaService.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeaService(
      id: serializer.fromJson<String>(json['id']),
      vesselName: serializer.fromJson<String>(json['vesselName']),
      imo: serializer.fromJson<String?>(json['imo']),
      rank: serializer.fromJson<String?>(json['rank']),
      signOn: serializer.fromJson<String>(json['signOn']),
      signOff: serializer.fromJson<String?>(json['signOff']),
      shipType: serializer.fromJson<String?>(json['shipType']),
      flag: serializer.fromJson<String?>(json['flag']),
      version: serializer.fromJson<int>(json['version']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      conflictJson: serializer.fromJson<String?>(json['conflictJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'vesselName': serializer.toJson<String>(vesselName),
      'imo': serializer.toJson<String?>(imo),
      'rank': serializer.toJson<String?>(rank),
      'signOn': serializer.toJson<String>(signOn),
      'signOff': serializer.toJson<String?>(signOff),
      'shipType': serializer.toJson<String?>(shipType),
      'flag': serializer.toJson<String?>(flag),
      'version': serializer.toJson<int>(version),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'dirty': serializer.toJson<bool>(dirty),
      'conflictJson': serializer.toJson<String?>(conflictJson),
    };
  }

  SeaService copyWith({
    String? id,
    String? vesselName,
    Value<String?> imo = const Value.absent(),
    Value<String?> rank = const Value.absent(),
    String? signOn,
    Value<String?> signOff = const Value.absent(),
    Value<String?> shipType = const Value.absent(),
    Value<String?> flag = const Value.absent(),
    int? version,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? dirty,
    Value<String?> conflictJson = const Value.absent(),
  }) => SeaService(
    id: id ?? this.id,
    vesselName: vesselName ?? this.vesselName,
    imo: imo.present ? imo.value : this.imo,
    rank: rank.present ? rank.value : this.rank,
    signOn: signOn ?? this.signOn,
    signOff: signOff.present ? signOff.value : this.signOff,
    shipType: shipType.present ? shipType.value : this.shipType,
    flag: flag.present ? flag.value : this.flag,
    version: version ?? this.version,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dirty: dirty ?? this.dirty,
    conflictJson: conflictJson.present ? conflictJson.value : this.conflictJson,
  );
  SeaService copyWithCompanion(SeaServicesCompanion data) {
    return SeaService(
      id: data.id.present ? data.id.value : this.id,
      vesselName: data.vesselName.present
          ? data.vesselName.value
          : this.vesselName,
      imo: data.imo.present ? data.imo.value : this.imo,
      rank: data.rank.present ? data.rank.value : this.rank,
      signOn: data.signOn.present ? data.signOn.value : this.signOn,
      signOff: data.signOff.present ? data.signOff.value : this.signOff,
      shipType: data.shipType.present ? data.shipType.value : this.shipType,
      flag: data.flag.present ? data.flag.value : this.flag,
      version: data.version.present ? data.version.value : this.version,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      conflictJson: data.conflictJson.present
          ? data.conflictJson.value
          : this.conflictJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeaService(')
          ..write('id: $id, ')
          ..write('vesselName: $vesselName, ')
          ..write('imo: $imo, ')
          ..write('rank: $rank, ')
          ..write('signOn: $signOn, ')
          ..write('signOff: $signOff, ')
          ..write('shipType: $shipType, ')
          ..write('flag: $flag, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('conflictJson: $conflictJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vesselName,
    imo,
    rank,
    signOn,
    signOff,
    shipType,
    flag,
    version,
    updatedAt,
    deletedAt,
    dirty,
    conflictJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeaService &&
          other.id == this.id &&
          other.vesselName == this.vesselName &&
          other.imo == this.imo &&
          other.rank == this.rank &&
          other.signOn == this.signOn &&
          other.signOff == this.signOff &&
          other.shipType == this.shipType &&
          other.flag == this.flag &&
          other.version == this.version &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dirty == this.dirty &&
          other.conflictJson == this.conflictJson);
}

class SeaServicesCompanion extends UpdateCompanion<SeaService> {
  final Value<String> id;
  final Value<String> vesselName;
  final Value<String?> imo;
  final Value<String?> rank;
  final Value<String> signOn;
  final Value<String?> signOff;
  final Value<String?> shipType;
  final Value<String?> flag;
  final Value<int> version;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<bool> dirty;
  final Value<String?> conflictJson;
  final Value<int> rowid;
  const SeaServicesCompanion({
    this.id = const Value.absent(),
    this.vesselName = const Value.absent(),
    this.imo = const Value.absent(),
    this.rank = const Value.absent(),
    this.signOn = const Value.absent(),
    this.signOff = const Value.absent(),
    this.shipType = const Value.absent(),
    this.flag = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.conflictJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeaServicesCompanion.insert({
    required String id,
    required String vesselName,
    this.imo = const Value.absent(),
    this.rank = const Value.absent(),
    required String signOn,
    this.signOff = const Value.absent(),
    this.shipType = const Value.absent(),
    this.flag = const Value.absent(),
    this.version = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.conflictJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       vesselName = Value(vesselName),
       signOn = Value(signOn),
       updatedAt = Value(updatedAt);
  static Insertable<SeaService> custom({
    Expression<String>? id,
    Expression<String>? vesselName,
    Expression<String>? imo,
    Expression<String>? rank,
    Expression<String>? signOn,
    Expression<String>? signOff,
    Expression<String>? shipType,
    Expression<String>? flag,
    Expression<int>? version,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<bool>? dirty,
    Expression<String>? conflictJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vesselName != null) 'vessel_name': vesselName,
      if (imo != null) 'imo': imo,
      if (rank != null) 'rank': rank,
      if (signOn != null) 'sign_on': signOn,
      if (signOff != null) 'sign_off': signOff,
      if (shipType != null) 'ship_type': shipType,
      if (flag != null) 'flag': flag,
      if (version != null) 'version': version,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dirty != null) 'dirty': dirty,
      if (conflictJson != null) 'conflict_json': conflictJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeaServicesCompanion copyWith({
    Value<String>? id,
    Value<String>? vesselName,
    Value<String?>? imo,
    Value<String?>? rank,
    Value<String>? signOn,
    Value<String?>? signOff,
    Value<String?>? shipType,
    Value<String?>? flag,
    Value<int>? version,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<bool>? dirty,
    Value<String?>? conflictJson,
    Value<int>? rowid,
  }) {
    return SeaServicesCompanion(
      id: id ?? this.id,
      vesselName: vesselName ?? this.vesselName,
      imo: imo ?? this.imo,
      rank: rank ?? this.rank,
      signOn: signOn ?? this.signOn,
      signOff: signOff ?? this.signOff,
      shipType: shipType ?? this.shipType,
      flag: flag ?? this.flag,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
      conflictJson: conflictJson ?? this.conflictJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (vesselName.present) {
      map['vessel_name'] = Variable<String>(vesselName.value);
    }
    if (imo.present) {
      map['imo'] = Variable<String>(imo.value);
    }
    if (rank.present) {
      map['rank'] = Variable<String>(rank.value);
    }
    if (signOn.present) {
      map['sign_on'] = Variable<String>(signOn.value);
    }
    if (signOff.present) {
      map['sign_off'] = Variable<String>(signOff.value);
    }
    if (shipType.present) {
      map['ship_type'] = Variable<String>(shipType.value);
    }
    if (flag.present) {
      map['flag'] = Variable<String>(flag.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (conflictJson.present) {
      map['conflict_json'] = Variable<String>(conflictJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeaServicesCompanion(')
          ..write('id: $id, ')
          ..write('vesselName: $vesselName, ')
          ..write('imo: $imo, ')
          ..write('rank: $rank, ')
          ..write('signOn: $signOn, ')
          ..write('signOff: $signOff, ')
          ..write('shipType: $shipType, ')
          ..write('flag: $flag, ')
          ..write('version: $version, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('conflictJson: $conflictJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $KeyValuesTable keyValues = $KeyValuesTable(this);
  late final $FeedItemsTable feedItems = $FeedItemsTable(this);
  late final $CachedDocumentsTable cachedDocuments = $CachedDocumentsTable(
    this,
  );
  late final $CertificatesTable certificates = $CertificatesTable(this);
  late final $ReminderLogTable reminderLog = $ReminderLogTable(this);
  late final $SeaServicesTable seaServices = $SeaServicesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    keyValues,
    feedItems,
    cachedDocuments,
    certificates,
    reminderLog,
    seaServices,
  ];
}

typedef $$KeyValuesTableCreateCompanionBuilder =
    KeyValuesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$KeyValuesTableUpdateCompanionBuilder =
    KeyValuesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$KeyValuesTableFilterComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KeyValuesTableOrderingComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KeyValuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$KeyValuesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KeyValuesTable,
          KeyValue,
          $$KeyValuesTableFilterComposer,
          $$KeyValuesTableOrderingComposer,
          $$KeyValuesTableAnnotationComposer,
          $$KeyValuesTableCreateCompanionBuilder,
          $$KeyValuesTableUpdateCompanionBuilder,
          (KeyValue, BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValue>),
          KeyValue,
          PrefetchHooks Function()
        > {
  $$KeyValuesTableTableManager(_$AppDatabase db, $KeyValuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KeyValuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KeyValuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KeyValuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KeyValuesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => KeyValuesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KeyValuesTable, KeyValue>(table),
                  BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValue>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KeyValuesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KeyValuesTable,
      KeyValue,
      $$KeyValuesTableFilterComposer,
      $$KeyValuesTableOrderingComposer,
      $$KeyValuesTableAnnotationComposer,
      $$KeyValuesTableCreateCompanionBuilder,
      $$KeyValuesTableUpdateCompanionBuilder,
      (KeyValue, BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValue>),
      KeyValue,
      PrefetchHooks Function()
    >;
typedef $$FeedItemsTableCreateCompanionBuilder =
    FeedItemsCompanion Function({
      required String alertId,
      required String kind,
      required String priority,
      required DateTime createdAt,
      Value<bool> read,
      Value<bool> readDirty,
      Value<String?> reason,
      Value<String?> documentId,
      Value<String?> certificateId,
      Value<String?> documentJson,
      Value<int> rowid,
    });
typedef $$FeedItemsTableUpdateCompanionBuilder =
    FeedItemsCompanion Function({
      Value<String> alertId,
      Value<String> kind,
      Value<String> priority,
      Value<DateTime> createdAt,
      Value<bool> read,
      Value<bool> readDirty,
      Value<String?> reason,
      Value<String?> documentId,
      Value<String?> certificateId,
      Value<String?> documentJson,
      Value<int> rowid,
    });

class $$FeedItemsTableFilterComposer
    extends Composer<_$AppDatabase, $FeedItemsTable> {
  $$FeedItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get alertId => $composableBuilder(
    column: $table.alertId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get read => $composableBuilder(
    column: $table.read,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get readDirty => $composableBuilder(
    column: $table.readDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get certificateId => $composableBuilder(
    column: $table.certificateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentJson => $composableBuilder(
    column: $table.documentJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FeedItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $FeedItemsTable> {
  $$FeedItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get alertId => $composableBuilder(
    column: $table.alertId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get read => $composableBuilder(
    column: $table.read,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get readDirty => $composableBuilder(
    column: $table.readDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get certificateId => $composableBuilder(
    column: $table.certificateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentJson => $composableBuilder(
    column: $table.documentJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FeedItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FeedItemsTable> {
  $$FeedItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get alertId =>
      $composableBuilder(column: $table.alertId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get read =>
      $composableBuilder(column: $table.read, builder: (column) => column);

  GeneratedColumn<bool> get readDirty =>
      $composableBuilder(column: $table.readDirty, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get certificateId => $composableBuilder(
    column: $table.certificateId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get documentJson => $composableBuilder(
    column: $table.documentJson,
    builder: (column) => column,
  );
}

class $$FeedItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FeedItemsTable,
          FeedItem,
          $$FeedItemsTableFilterComposer,
          $$FeedItemsTableOrderingComposer,
          $$FeedItemsTableAnnotationComposer,
          $$FeedItemsTableCreateCompanionBuilder,
          $$FeedItemsTableUpdateCompanionBuilder,
          (FeedItem, BaseReferences<_$AppDatabase, $FeedItemsTable, FeedItem>),
          FeedItem,
          PrefetchHooks Function()
        > {
  $$FeedItemsTableTableManager(_$AppDatabase db, $FeedItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeedItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeedItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeedItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> alertId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> priority = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> read = const Value.absent(),
                Value<bool> readDirty = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<String?> documentId = const Value.absent(),
                Value<String?> certificateId = const Value.absent(),
                Value<String?> documentJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FeedItemsCompanion(
                alertId: alertId,
                kind: kind,
                priority: priority,
                createdAt: createdAt,
                read: read,
                readDirty: readDirty,
                reason: reason,
                documentId: documentId,
                certificateId: certificateId,
                documentJson: documentJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String alertId,
                required String kind,
                required String priority,
                required DateTime createdAt,
                Value<bool> read = const Value.absent(),
                Value<bool> readDirty = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<String?> documentId = const Value.absent(),
                Value<String?> certificateId = const Value.absent(),
                Value<String?> documentJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FeedItemsCompanion.insert(
                alertId: alertId,
                kind: kind,
                priority: priority,
                createdAt: createdAt,
                read: read,
                readDirty: readDirty,
                reason: reason,
                documentId: documentId,
                certificateId: certificateId,
                documentJson: documentJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FeedItemsTable, FeedItem>(table),
                  BaseReferences<_$AppDatabase, $FeedItemsTable, FeedItem>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FeedItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FeedItemsTable,
      FeedItem,
      $$FeedItemsTableFilterComposer,
      $$FeedItemsTableOrderingComposer,
      $$FeedItemsTableAnnotationComposer,
      $$FeedItemsTableCreateCompanionBuilder,
      $$FeedItemsTableUpdateCompanionBuilder,
      (FeedItem, BaseReferences<_$AppDatabase, $FeedItemsTable, FeedItem>),
      FeedItem,
      PrefetchHooks Function()
    >;
typedef $$CachedDocumentsTableCreateCompanionBuilder =
    CachedDocumentsCompanion Function({
      required String id,
      required String title,
      Value<String?> circularNumber,
      Value<String?> publishedDate,
      required String docType,
      required String priority,
      Value<String?> summaryShort,
      Value<String?> detailJson,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedDocumentsTableUpdateCompanionBuilder =
    CachedDocumentsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> circularNumber,
      Value<String?> publishedDate,
      Value<String> docType,
      Value<String> priority,
      Value<String?> summaryShort,
      Value<String?> detailJson,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedDocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedDocumentsTable> {
  $$CachedDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get circularNumber => $composableBuilder(
    column: $table.circularNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publishedDate => $composableBuilder(
    column: $table.publishedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get docType => $composableBuilder(
    column: $table.docType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryShort => $composableBuilder(
    column: $table.summaryShort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailJson => $composableBuilder(
    column: $table.detailJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedDocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedDocumentsTable> {
  $$CachedDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get circularNumber => $composableBuilder(
    column: $table.circularNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publishedDate => $composableBuilder(
    column: $table.publishedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get docType => $composableBuilder(
    column: $table.docType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryShort => $composableBuilder(
    column: $table.summaryShort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailJson => $composableBuilder(
    column: $table.detailJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedDocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedDocumentsTable> {
  $$CachedDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get circularNumber => $composableBuilder(
    column: $table.circularNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get publishedDate => $composableBuilder(
    column: $table.publishedDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get docType =>
      $composableBuilder(column: $table.docType, builder: (column) => column);

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get summaryShort => $composableBuilder(
    column: $table.summaryShort,
    builder: (column) => column,
  );

  GeneratedColumn<String> get detailJson => $composableBuilder(
    column: $table.detailJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedDocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedDocumentsTable,
          CachedDocument,
          $$CachedDocumentsTableFilterComposer,
          $$CachedDocumentsTableOrderingComposer,
          $$CachedDocumentsTableAnnotationComposer,
          $$CachedDocumentsTableCreateCompanionBuilder,
          $$CachedDocumentsTableUpdateCompanionBuilder,
          (
            CachedDocument,
            BaseReferences<
              _$AppDatabase,
              $CachedDocumentsTable,
              CachedDocument
            >,
          ),
          CachedDocument,
          PrefetchHooks Function()
        > {
  $$CachedDocumentsTableTableManager(
    _$AppDatabase db,
    $CachedDocumentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedDocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> circularNumber = const Value.absent(),
                Value<String?> publishedDate = const Value.absent(),
                Value<String> docType = const Value.absent(),
                Value<String> priority = const Value.absent(),
                Value<String?> summaryShort = const Value.absent(),
                Value<String?> detailJson = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedDocumentsCompanion(
                id: id,
                title: title,
                circularNumber: circularNumber,
                publishedDate: publishedDate,
                docType: docType,
                priority: priority,
                summaryShort: summaryShort,
                detailJson: detailJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> circularNumber = const Value.absent(),
                Value<String?> publishedDate = const Value.absent(),
                required String docType,
                required String priority,
                Value<String?> summaryShort = const Value.absent(),
                Value<String?> detailJson = const Value.absent(),
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedDocumentsCompanion.insert(
                id: id,
                title: title,
                circularNumber: circularNumber,
                publishedDate: publishedDate,
                docType: docType,
                priority: priority,
                summaryShort: summaryShort,
                detailJson: detailJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedDocumentsTable, CachedDocument>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedDocumentsTable,
                    CachedDocument
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedDocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedDocumentsTable,
      CachedDocument,
      $$CachedDocumentsTableFilterComposer,
      $$CachedDocumentsTableOrderingComposer,
      $$CachedDocumentsTableAnnotationComposer,
      $$CachedDocumentsTableCreateCompanionBuilder,
      $$CachedDocumentsTableUpdateCompanionBuilder,
      (
        CachedDocument,
        BaseReferences<_$AppDatabase, $CachedDocumentsTable, CachedDocument>,
      ),
      CachedDocument,
      PrefetchHooks Function()
    >;
typedef $$CertificatesTableCreateCompanionBuilder =
    CertificatesCompanion Function({
      required String id,
      required String type,
      Value<String?> subtype,
      Value<String?> number,
      Value<String?> issuingAuthority,
      Value<String?> issueDate,
      Value<String?> expiryDate,
      Value<int> version,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> dirty,
      Value<String?> filePath,
      Value<String?> fileName,
      Value<String?> conflictJson,
      Value<int> rowid,
    });
typedef $$CertificatesTableUpdateCompanionBuilder =
    CertificatesCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String?> subtype,
      Value<String?> number,
      Value<String?> issuingAuthority,
      Value<String?> issueDate,
      Value<String?> expiryDate,
      Value<int> version,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> dirty,
      Value<String?> filePath,
      Value<String?> fileName,
      Value<String?> conflictJson,
      Value<int> rowid,
    });

class $$CertificatesTableFilterComposer
    extends Composer<_$AppDatabase, $CertificatesTable> {
  $$CertificatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtype => $composableBuilder(
    column: $table.subtype,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get issuingAuthority => $composableBuilder(
    column: $table.issuingAuthority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get issueDate => $composableBuilder(
    column: $table.issueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictJson => $composableBuilder(
    column: $table.conflictJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CertificatesTableOrderingComposer
    extends Composer<_$AppDatabase, $CertificatesTable> {
  $$CertificatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtype => $composableBuilder(
    column: $table.subtype,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get issuingAuthority => $composableBuilder(
    column: $table.issuingAuthority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get issueDate => $composableBuilder(
    column: $table.issueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictJson => $composableBuilder(
    column: $table.conflictJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CertificatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CertificatesTable> {
  $$CertificatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get subtype =>
      $composableBuilder(column: $table.subtype, builder: (column) => column);

  GeneratedColumn<String> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get issuingAuthority => $composableBuilder(
    column: $table.issuingAuthority,
    builder: (column) => column,
  );

  GeneratedColumn<String> get issueDate =>
      $composableBuilder(column: $table.issueDate, builder: (column) => column);

  GeneratedColumn<String> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get conflictJson => $composableBuilder(
    column: $table.conflictJson,
    builder: (column) => column,
  );
}

class $$CertificatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CertificatesTable,
          Certificate,
          $$CertificatesTableFilterComposer,
          $$CertificatesTableOrderingComposer,
          $$CertificatesTableAnnotationComposer,
          $$CertificatesTableCreateCompanionBuilder,
          $$CertificatesTableUpdateCompanionBuilder,
          (
            Certificate,
            BaseReferences<_$AppDatabase, $CertificatesTable, Certificate>,
          ),
          Certificate,
          PrefetchHooks Function()
        > {
  $$CertificatesTableTableManager(_$AppDatabase db, $CertificatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CertificatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CertificatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CertificatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> subtype = const Value.absent(),
                Value<String?> number = const Value.absent(),
                Value<String?> issuingAuthority = const Value.absent(),
                Value<String?> issueDate = const Value.absent(),
                Value<String?> expiryDate = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String?> fileName = const Value.absent(),
                Value<String?> conflictJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CertificatesCompanion(
                id: id,
                type: type,
                subtype: subtype,
                number: number,
                issuingAuthority: issuingAuthority,
                issueDate: issueDate,
                expiryDate: expiryDate,
                version: version,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                filePath: filePath,
                fileName: fileName,
                conflictJson: conflictJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                Value<String?> subtype = const Value.absent(),
                Value<String?> number = const Value.absent(),
                Value<String?> issuingAuthority = const Value.absent(),
                Value<String?> issueDate = const Value.absent(),
                Value<String?> expiryDate = const Value.absent(),
                Value<int> version = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String?> fileName = const Value.absent(),
                Value<String?> conflictJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CertificatesCompanion.insert(
                id: id,
                type: type,
                subtype: subtype,
                number: number,
                issuingAuthority: issuingAuthority,
                issueDate: issueDate,
                expiryDate: expiryDate,
                version: version,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                filePath: filePath,
                fileName: fileName,
                conflictJson: conflictJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CertificatesTable, Certificate>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CertificatesTable,
                    Certificate
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CertificatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CertificatesTable,
      Certificate,
      $$CertificatesTableFilterComposer,
      $$CertificatesTableOrderingComposer,
      $$CertificatesTableAnnotationComposer,
      $$CertificatesTableCreateCompanionBuilder,
      $$CertificatesTableUpdateCompanionBuilder,
      (
        Certificate,
        BaseReferences<_$AppDatabase, $CertificatesTable, Certificate>,
      ),
      Certificate,
      PrefetchHooks Function()
    >;
typedef $$ReminderLogTableCreateCompanionBuilder =
    ReminderLogCompanion Function({
      required String certificateId,
      required String expiryDate,
      required int bucket,
      required DateTime shownAt,
      Value<int> rowid,
    });
typedef $$ReminderLogTableUpdateCompanionBuilder =
    ReminderLogCompanion Function({
      Value<String> certificateId,
      Value<String> expiryDate,
      Value<int> bucket,
      Value<DateTime> shownAt,
      Value<int> rowid,
    });

class $$ReminderLogTableFilterComposer
    extends Composer<_$AppDatabase, $ReminderLogTable> {
  $$ReminderLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get certificateId => $composableBuilder(
    column: $table.certificateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bucket => $composableBuilder(
    column: $table.bucket,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get shownAt => $composableBuilder(
    column: $table.shownAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReminderLogTableOrderingComposer
    extends Composer<_$AppDatabase, $ReminderLogTable> {
  $$ReminderLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get certificateId => $composableBuilder(
    column: $table.certificateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bucket => $composableBuilder(
    column: $table.bucket,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get shownAt => $composableBuilder(
    column: $table.shownAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReminderLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReminderLogTable> {
  $$ReminderLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get certificateId => $composableBuilder(
    column: $table.certificateId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bucket =>
      $composableBuilder(column: $table.bucket, builder: (column) => column);

  GeneratedColumn<DateTime> get shownAt =>
      $composableBuilder(column: $table.shownAt, builder: (column) => column);
}

class $$ReminderLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReminderLogTable,
          ReminderLogData,
          $$ReminderLogTableFilterComposer,
          $$ReminderLogTableOrderingComposer,
          $$ReminderLogTableAnnotationComposer,
          $$ReminderLogTableCreateCompanionBuilder,
          $$ReminderLogTableUpdateCompanionBuilder,
          (
            ReminderLogData,
            BaseReferences<_$AppDatabase, $ReminderLogTable, ReminderLogData>,
          ),
          ReminderLogData,
          PrefetchHooks Function()
        > {
  $$ReminderLogTableTableManager(_$AppDatabase db, $ReminderLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReminderLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReminderLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReminderLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> certificateId = const Value.absent(),
                Value<String> expiryDate = const Value.absent(),
                Value<int> bucket = const Value.absent(),
                Value<DateTime> shownAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReminderLogCompanion(
                certificateId: certificateId,
                expiryDate: expiryDate,
                bucket: bucket,
                shownAt: shownAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String certificateId,
                required String expiryDate,
                required int bucket,
                required DateTime shownAt,
                Value<int> rowid = const Value.absent(),
              }) => ReminderLogCompanion.insert(
                certificateId: certificateId,
                expiryDate: expiryDate,
                bucket: bucket,
                shownAt: shownAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReminderLogTable, ReminderLogData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ReminderLogTable,
                    ReminderLogData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReminderLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReminderLogTable,
      ReminderLogData,
      $$ReminderLogTableFilterComposer,
      $$ReminderLogTableOrderingComposer,
      $$ReminderLogTableAnnotationComposer,
      $$ReminderLogTableCreateCompanionBuilder,
      $$ReminderLogTableUpdateCompanionBuilder,
      (
        ReminderLogData,
        BaseReferences<_$AppDatabase, $ReminderLogTable, ReminderLogData>,
      ),
      ReminderLogData,
      PrefetchHooks Function()
    >;
typedef $$SeaServicesTableCreateCompanionBuilder =
    SeaServicesCompanion Function({
      required String id,
      required String vesselName,
      Value<String?> imo,
      Value<String?> rank,
      required String signOn,
      Value<String?> signOff,
      Value<String?> shipType,
      Value<String?> flag,
      Value<int> version,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> dirty,
      Value<String?> conflictJson,
      Value<int> rowid,
    });
typedef $$SeaServicesTableUpdateCompanionBuilder =
    SeaServicesCompanion Function({
      Value<String> id,
      Value<String> vesselName,
      Value<String?> imo,
      Value<String?> rank,
      Value<String> signOn,
      Value<String?> signOff,
      Value<String?> shipType,
      Value<String?> flag,
      Value<int> version,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> dirty,
      Value<String?> conflictJson,
      Value<int> rowid,
    });

class $$SeaServicesTableFilterComposer
    extends Composer<_$AppDatabase, $SeaServicesTable> {
  $$SeaServicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vesselName => $composableBuilder(
    column: $table.vesselName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imo => $composableBuilder(
    column: $table.imo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signOn => $composableBuilder(
    column: $table.signOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signOff => $composableBuilder(
    column: $table.signOff,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shipType => $composableBuilder(
    column: $table.shipType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get flag => $composableBuilder(
    column: $table.flag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictJson => $composableBuilder(
    column: $table.conflictJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SeaServicesTableOrderingComposer
    extends Composer<_$AppDatabase, $SeaServicesTable> {
  $$SeaServicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vesselName => $composableBuilder(
    column: $table.vesselName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imo => $composableBuilder(
    column: $table.imo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signOn => $composableBuilder(
    column: $table.signOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signOff => $composableBuilder(
    column: $table.signOff,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shipType => $composableBuilder(
    column: $table.shipType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get flag => $composableBuilder(
    column: $table.flag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictJson => $composableBuilder(
    column: $table.conflictJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeaServicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SeaServicesTable> {
  $$SeaServicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get vesselName => $composableBuilder(
    column: $table.vesselName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imo =>
      $composableBuilder(column: $table.imo, builder: (column) => column);

  GeneratedColumn<String> get rank =>
      $composableBuilder(column: $table.rank, builder: (column) => column);

  GeneratedColumn<String> get signOn =>
      $composableBuilder(column: $table.signOn, builder: (column) => column);

  GeneratedColumn<String> get signOff =>
      $composableBuilder(column: $table.signOff, builder: (column) => column);

  GeneratedColumn<String> get shipType =>
      $composableBuilder(column: $table.shipType, builder: (column) => column);

  GeneratedColumn<String> get flag =>
      $composableBuilder(column: $table.flag, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get conflictJson => $composableBuilder(
    column: $table.conflictJson,
    builder: (column) => column,
  );
}

class $$SeaServicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SeaServicesTable,
          SeaService,
          $$SeaServicesTableFilterComposer,
          $$SeaServicesTableOrderingComposer,
          $$SeaServicesTableAnnotationComposer,
          $$SeaServicesTableCreateCompanionBuilder,
          $$SeaServicesTableUpdateCompanionBuilder,
          (
            SeaService,
            BaseReferences<_$AppDatabase, $SeaServicesTable, SeaService>,
          ),
          SeaService,
          PrefetchHooks Function()
        > {
  $$SeaServicesTableTableManager(_$AppDatabase db, $SeaServicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeaServicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeaServicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeaServicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> vesselName = const Value.absent(),
                Value<String?> imo = const Value.absent(),
                Value<String?> rank = const Value.absent(),
                Value<String> signOn = const Value.absent(),
                Value<String?> signOff = const Value.absent(),
                Value<String?> shipType = const Value.absent(),
                Value<String?> flag = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String?> conflictJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeaServicesCompanion(
                id: id,
                vesselName: vesselName,
                imo: imo,
                rank: rank,
                signOn: signOn,
                signOff: signOff,
                shipType: shipType,
                flag: flag,
                version: version,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                conflictJson: conflictJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String vesselName,
                Value<String?> imo = const Value.absent(),
                Value<String?> rank = const Value.absent(),
                required String signOn,
                Value<String?> signOff = const Value.absent(),
                Value<String?> shipType = const Value.absent(),
                Value<String?> flag = const Value.absent(),
                Value<int> version = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String?> conflictJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeaServicesCompanion.insert(
                id: id,
                vesselName: vesselName,
                imo: imo,
                rank: rank,
                signOn: signOn,
                signOff: signOff,
                shipType: shipType,
                flag: flag,
                version: version,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                conflictJson: conflictJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SeaServicesTable, SeaService>(table),
                  BaseReferences<_$AppDatabase, $SeaServicesTable, SeaService>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SeaServicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SeaServicesTable,
      SeaService,
      $$SeaServicesTableFilterComposer,
      $$SeaServicesTableOrderingComposer,
      $$SeaServicesTableAnnotationComposer,
      $$SeaServicesTableCreateCompanionBuilder,
      $$SeaServicesTableUpdateCompanionBuilder,
      (
        SeaService,
        BaseReferences<_$AppDatabase, $SeaServicesTable, SeaService>,
      ),
      SeaService,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$KeyValuesTableTableManager get keyValues =>
      $$KeyValuesTableTableManager(_db, _db.keyValues);
  $$FeedItemsTableTableManager get feedItems =>
      $$FeedItemsTableTableManager(_db, _db.feedItems);
  $$CachedDocumentsTableTableManager get cachedDocuments =>
      $$CachedDocumentsTableTableManager(_db, _db.cachedDocuments);
  $$CertificatesTableTableManager get certificates =>
      $$CertificatesTableTableManager(_db, _db.certificates);
  $$ReminderLogTableTableManager get reminderLog =>
      $$ReminderLogTableTableManager(_db, _db.reminderLog);
  $$SeaServicesTableTableManager get seaServices =>
      $$SeaServicesTableTableManager(_db, _db.seaServices);
}
