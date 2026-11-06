// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_app_database.dart';

// ignore_for_file: type=lint
class $DbSettingsTable extends DbSettings
    with TableInfo<$DbSettingsTable, DbSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbSetting> instance, {
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
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  DbSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $DbSettingsTable createAlias(String alias) {
    return $DbSettingsTable(attachedDatabase, alias);
  }
}

class DbSetting extends DataClass implements Insertable<DbSetting> {
  final String key;
  final String json;
  const DbSetting({required this.key, required this.json});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['json'] = Variable<String>(json);
    return map;
  }

  DbSettingsCompanion toCompanion(bool nullToAbsent) {
    return DbSettingsCompanion(key: Value(key), json: Value(json));
  }

  factory DbSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbSetting(
      key: serializer.fromJson<String>(json['key']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'json': serializer.toJson<String>(json),
    };
  }

  DbSetting copyWith({String? key, String? json}) =>
      DbSetting(key: key ?? this.key, json: json ?? this.json);
  DbSetting copyWithCompanion(DbSettingsCompanion data) {
    return DbSetting(
      key: data.key.present ? data.key.value : this.key,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbSetting(')
          ..write('key: $key, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbSetting && other.key == this.key && other.json == this.json);
}

class DbSettingsCompanion extends UpdateCompanion<DbSetting> {
  final Value<String> key;
  final Value<String> json;
  final Value<int> rowid;
  const DbSettingsCompanion({
    this.key = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DbSettingsCompanion.insert({
    required String key,
    required String json,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       json = Value(json);
  static Insertable<DbSetting> custom({
    Expression<String>? key,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DbSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? json,
    Value<int>? rowid,
  }) {
    return DbSettingsCompanion(
      key: key ?? this.key,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbSettingsCompanion(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DbMetricsTable extends DbMetrics
    with TableInfo<$DbMetricsTable, DbMetric> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbMetricsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<int> recordedAt = GeneratedColumn<int>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _labelsMeta = const VerificationMeta('labels');
  @override
  late final GeneratedColumn<String> labels = GeneratedColumn<String>(
    'labels',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant<String>('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, recordedAt, value, labels];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_metrics';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbMetric> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('labels')) {
      context.handle(
        _labelsMeta,
        labels.isAcceptableOrUnknown(data['labels']!, _labelsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbMetric map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbMetric(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recorded_at'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value'],
      ),
      labels: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}labels'],
      )!,
    );
  }

  @override
  $DbMetricsTable createAlias(String alias) {
    return $DbMetricsTable(attachedDatabase, alias);
  }
}

class DbMetric extends DataClass implements Insertable<DbMetric> {
  final int id;
  final String name;
  final int recordedAt;
  final double? value;
  final String labels;
  const DbMetric({
    required this.id,
    required this.name,
    required this.recordedAt,
    this.value,
    required this.labels,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['recorded_at'] = Variable<int>(recordedAt);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<double>(value);
    }
    map['labels'] = Variable<String>(labels);
    return map;
  }

  DbMetricsCompanion toCompanion(bool nullToAbsent) {
    return DbMetricsCompanion(
      id: Value(id),
      name: Value(name),
      recordedAt: Value(recordedAt),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      labels: Value(labels),
    );
  }

  factory DbMetric.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbMetric(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      recordedAt: serializer.fromJson<int>(json['recordedAt']),
      value: serializer.fromJson<double?>(json['value']),
      labels: serializer.fromJson<String>(json['labels']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'recordedAt': serializer.toJson<int>(recordedAt),
      'value': serializer.toJson<double?>(value),
      'labels': serializer.toJson<String>(labels),
    };
  }

  DbMetric copyWith({
    int? id,
    String? name,
    int? recordedAt,
    Value<double?> value = const Value.absent(),
    String? labels,
  }) => DbMetric(
    id: id ?? this.id,
    name: name ?? this.name,
    recordedAt: recordedAt ?? this.recordedAt,
    value: value.present ? value.value : this.value,
    labels: labels ?? this.labels,
  );
  DbMetric copyWithCompanion(DbMetricsCompanion data) {
    return DbMetric(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
      value: data.value.present ? data.value.value : this.value,
      labels: data.labels.present ? data.labels.value : this.labels,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbMetric(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('value: $value, ')
          ..write('labels: $labels')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, recordedAt, value, labels);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbMetric &&
          other.id == this.id &&
          other.name == this.name &&
          other.recordedAt == this.recordedAt &&
          other.value == this.value &&
          other.labels == this.labels);
}

class DbMetricsCompanion extends UpdateCompanion<DbMetric> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> recordedAt;
  final Value<double?> value;
  final Value<String> labels;
  const DbMetricsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.value = const Value.absent(),
    this.labels = const Value.absent(),
  });
  DbMetricsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int recordedAt,
    this.value = const Value.absent(),
    this.labels = const Value.absent(),
  }) : name = Value(name),
       recordedAt = Value(recordedAt);
  static Insertable<DbMetric> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? recordedAt,
    Expression<double>? value,
    Expression<String>? labels,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (value != null) 'value': value,
      if (labels != null) 'labels': labels,
    });
  }

  DbMetricsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? recordedAt,
    Value<double?>? value,
    Value<String>? labels,
  }) {
    return DbMetricsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      recordedAt: recordedAt ?? this.recordedAt,
      value: value ?? this.value,
      labels: labels ?? this.labels,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<int>(recordedAt.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (labels.present) {
      map['labels'] = Variable<String>(labels.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbMetricsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('value: $value, ')
          ..write('labels: $labels')
          ..write(')'))
        .toString();
  }
}

abstract class _$DriftAppDatabase extends GeneratedDatabase {
  _$DriftAppDatabase(QueryExecutor e) : super(e);
  $DriftAppDatabaseManager get managers => $DriftAppDatabaseManager(this);
  late final $DbSettingsTable dbSettings = $DbSettingsTable(this);
  late final $DbMetricsTable dbMetrics = $DbMetricsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [dbSettings, dbMetrics];
}

typedef $$DbSettingsTableCreateCompanionBuilder = DbSettingsCompanion Function({
  required String key,
  required String json,
  Value<int> rowid,
});
typedef $$DbSettingsTableUpdateCompanionBuilder = DbSettingsCompanion Function({
  Value<String> key,
  Value<String> json,
  Value<int> rowid,
});

class $$DbSettingsTableFilterComposer
    extends Composer<_$DriftAppDatabase, $DbSettingsTable> {
  $$DbSettingsTableFilterComposer({
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

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbSettingsTableOrderingComposer
    extends Composer<_$DriftAppDatabase, $DbSettingsTable> {
  $$DbSettingsTableOrderingComposer({
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

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbSettingsTableAnnotationComposer
    extends Composer<_$DriftAppDatabase, $DbSettingsTable> {
  $$DbSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$DbSettingsTableTableManager
    extends
        RootTableManager<
          _$DriftAppDatabase,
          $DbSettingsTable,
          DbSetting,
          $$DbSettingsTableFilterComposer,
          $$DbSettingsTableOrderingComposer,
          $$DbSettingsTableAnnotationComposer,
          $$DbSettingsTableCreateCompanionBuilder,
          $$DbSettingsTableUpdateCompanionBuilder,
          (
            DbSetting,
            BaseReferences<_$DriftAppDatabase, $DbSettingsTable, DbSetting>,
          ),
          DbSetting,
          PrefetchHooks Function()
        > {
  $$DbSettingsTableTableManager(_$DriftAppDatabase db, $DbSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => DbSettingsCompanion(key: key, json: json, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String json,
            Value<int> rowid = const Value.absent(),
          }) => DbSettingsCompanion.insert(key: key, json: json, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$DriftAppDatabase,
      $DbSettingsTable,
      DbSetting,
      $$DbSettingsTableFilterComposer,
      $$DbSettingsTableOrderingComposer,
      $$DbSettingsTableAnnotationComposer,
      $$DbSettingsTableCreateCompanionBuilder,
      $$DbSettingsTableUpdateCompanionBuilder,
      (
        DbSetting,
        BaseReferences<_$DriftAppDatabase, $DbSettingsTable, DbSetting>,
      ),
      DbSetting,
      PrefetchHooks Function()
    >;
typedef $$DbMetricsTableCreateCompanionBuilder = DbMetricsCompanion Function({
  Value<int> id,
  required String name,
  required int recordedAt,
  Value<double?> value,
  Value<String> labels,
});
typedef $$DbMetricsTableUpdateCompanionBuilder = DbMetricsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int> recordedAt,
  Value<double?> value,
  Value<String> labels,
});

class $$DbMetricsTableFilterComposer
    extends Composer<_$DriftAppDatabase, $DbMetricsTable> {
  $$DbMetricsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get labels => $composableBuilder(
    column: $table.labels,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbMetricsTableOrderingComposer
    extends Composer<_$DriftAppDatabase, $DbMetricsTable> {
  $$DbMetricsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get labels => $composableBuilder(
    column: $table.labels,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbMetricsTableAnnotationComposer
    extends Composer<_$DriftAppDatabase, $DbMetricsTable> {
  $$DbMetricsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get labels =>
      $composableBuilder(column: $table.labels, builder: (column) => column);
}

class $$DbMetricsTableTableManager
    extends
        RootTableManager<
          _$DriftAppDatabase,
          $DbMetricsTable,
          DbMetric,
          $$DbMetricsTableFilterComposer,
          $$DbMetricsTableOrderingComposer,
          $$DbMetricsTableAnnotationComposer,
          $$DbMetricsTableCreateCompanionBuilder,
          $$DbMetricsTableUpdateCompanionBuilder,
          (
            DbMetric,
            BaseReferences<_$DriftAppDatabase, $DbMetricsTable, DbMetric>,
          ),
          DbMetric,
          PrefetchHooks Function()
        > {
  $$DbMetricsTableTableManager(_$DriftAppDatabase db, $DbMetricsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbMetricsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbMetricsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbMetricsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> recordedAt = const Value.absent(),
                Value<double?> value = const Value.absent(),
                Value<String> labels = const Value.absent(),
              }) => DbMetricsCompanion(
                id: id,
                name: name,
                recordedAt: recordedAt,
                value: value,
                labels: labels,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int recordedAt,
                Value<double?> value = const Value.absent(),
                Value<String> labels = const Value.absent(),
              }) => DbMetricsCompanion.insert(
                id: id,
                name: name,
                recordedAt: recordedAt,
                value: value,
                labels: labels,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbMetricsTableProcessedTableManager =
    ProcessedTableManager<
      _$DriftAppDatabase,
      $DbMetricsTable,
      DbMetric,
      $$DbMetricsTableFilterComposer,
      $$DbMetricsTableOrderingComposer,
      $$DbMetricsTableAnnotationComposer,
      $$DbMetricsTableCreateCompanionBuilder,
      $$DbMetricsTableUpdateCompanionBuilder,
      (DbMetric, BaseReferences<_$DriftAppDatabase, $DbMetricsTable, DbMetric>),
      DbMetric,
      PrefetchHooks Function()
    >;

class $DriftAppDatabaseManager {
  final _$DriftAppDatabase _db;
  $DriftAppDatabaseManager(this._db);
  $$DbSettingsTableTableManager get dbSettings =>
      $$DbSettingsTableTableManager(_db, _db.dbSettings);
  $$DbMetricsTableTableManager get dbMetrics =>
      $$DbMetricsTableTableManager(_db, _db.dbMetrics);
}
