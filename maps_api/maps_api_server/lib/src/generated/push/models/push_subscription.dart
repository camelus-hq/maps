/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _ida;
import 'package:maps_api_server/src/generated/protocol.dart' as _i0opuntk;
import 'package:serverpod/serverpod.dart' as _is;

/// One push destination for one Nostr identity on one relay.
///
/// A user can have several rows: one per (relay, token) pair, so they can be
/// reached on any of their relays and from any of their devices. The token is
/// either an FCM registration token (Firebase transport) or a UnifiedPush
/// endpoint URL; `transport` records which, so the forwarder knows how to send.
abstract class PushSubscription
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  PushSubscription._({
    this.id,
    required this.pubKey,
    required this.relay,
    required this.token,
    required this.transport,
    this.kinds,
  });

  factory PushSubscription({
    int? id,
    required String pubKey,
    required String relay,
    required String token,
    required String transport,
    List<int>? kinds,
  }) = _PushSubscriptionImpl;

  factory PushSubscription.fromJson(Map<String, dynamic> jsonSerialization) {
    return PushSubscription(
      id: jsonSerialization['id'] as int?,
      pubKey: jsonSerialization['pubKey'] as String,
      relay: jsonSerialization['relay'] as String,
      token: jsonSerialization['token'] as String,
      transport: jsonSerialization['transport'] as String,
      kinds: jsonSerialization['kinds'] == null
          ? null
          : _i0opuntk.Protocol().deserialize<List<int>>(
              jsonSerialization['kinds'],
            ),
    );
  }

  static final t = PushSubscriptionTable();

  static const db = PushSubscriptionRepository._();

  @override
  int? id;

  /// The recipient's Nostr public key (64-character lowercase hex).
  String pubKey;

  /// A relay the recipient's events can be picked up on.
  String relay;

  /// An FCM registration token, or a UnifiedPush endpoint URL.
  String token;

  /// The transport for [token]: `firebase` or `unifiedpush`.
  String transport;

  /// The outer event kinds the recipient wants pushed. `1059` is a NIP-59 gift
  /// wrap, which carries every private notification (live share, DM, …).
  List<int>? kinds;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [PushSubscription]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PushSubscription copyWith({
    int? id,
    String? pubKey,
    String? relay,
    String? token,
    String? transport,
    List<int>? kinds = const _is.$UndefinedList<int>(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PushSubscription',
      if (id != null) 'id': id,
      'pubKey': pubKey,
      'relay': relay,
      'token': token,
      'transport': transport,
      if (kinds != null) 'kinds': kinds?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PushSubscription',
      if (id != null) 'id': id,
      'pubKey': pubKey,
      'relay': relay,
      'token': token,
      'transport': transport,
      if (kinds != null) 'kinds': kinds?.toJson(),
    };
  }

  static PushSubscriptionInclude include() {
    return PushSubscriptionInclude._();
  }

  static PushSubscriptionIncludeList includeList({
    _is.WhereExpressionBuilder<PushSubscriptionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PushSubscriptionTable>? orderBy,
    _is.OrderByListBuilder<PushSubscriptionTable>? orderByList,
    PushSubscriptionInclude? include,
  }) {
    return PushSubscriptionIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(PushSubscription.t),
      orderByList: orderByList?.call(PushSubscription.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PushSubscriptionImpl extends PushSubscription {
  _PushSubscriptionImpl({
    int? id,
    required String pubKey,
    required String relay,
    required String token,
    required String transport,
    List<int>? kinds,
  }) : super._(
         id: id,
         pubKey: pubKey,
         relay: relay,
         token: token,
         transport: transport,
         kinds: kinds,
       );

  /// Returns a shallow copy of this [PushSubscription]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PushSubscription copyWith({
    Object? id = _Undefined,
    String? pubKey,
    String? relay,
    String? token,
    String? transport,
    List<int>? kinds = const _is.$UndefinedList<int>(),
  }) {
    return PushSubscription(
      id: id is int? ? id : this.id,
      pubKey: pubKey ?? this.pubKey,
      relay: relay ?? this.relay,
      token: token ?? this.token,
      transport: transport ?? this.transport,
      kinds: kinds is _is.UndefinedSentinel
          ? this.kinds?.map((e0) => e0).toList()
          : kinds,
    );
  }
}

class PushSubscriptionUpdateTable
    extends _is.UpdateTable<PushSubscriptionTable> {
  PushSubscriptionUpdateTable(super.table);

  _is.ColumnValue<String, String> pubKey(String value) => _is.ColumnValue(
    table.pubKey,
    value,
  );

  _is.ColumnValue<String, String> relay(String value) => _is.ColumnValue(
    table.relay,
    value,
  );

  _is.ColumnValue<String, String> token(String value) => _is.ColumnValue(
    table.token,
    value,
  );

  _is.ColumnValue<String, String> transport(String value) => _is.ColumnValue(
    table.transport,
    value,
  );

  _is.ColumnValue<List<int>, List<int>> kinds(List<int>? value) =>
      _is.ColumnValue(
        table.kinds,
        value,
      );
}

class PushSubscriptionTable extends _is.Table<int?> {
  PushSubscriptionTable({super.tableRelation})
    : super(tableName: 'push_subscriptions') {
    updateTable = PushSubscriptionUpdateTable(this);
    pubKey = _is.ColumnString(
      'pubKey',
      this,
    );
    relay = _is.ColumnString(
      'relay',
      this,
    );
    token = _is.ColumnString(
      'token',
      this,
    );
    transport = _is.ColumnString(
      'transport',
      this,
    );
    kinds = _is.ColumnSerializable<List<int>>(
      'kinds',
      this,
    );
  }

  late final PushSubscriptionUpdateTable updateTable;

  /// The recipient's Nostr public key (64-character lowercase hex).
  late final _is.ColumnString pubKey;

  /// A relay the recipient's events can be picked up on.
  late final _is.ColumnString relay;

  /// An FCM registration token, or a UnifiedPush endpoint URL.
  late final _is.ColumnString token;

  /// The transport for [token]: `firebase` or `unifiedpush`.
  late final _is.ColumnString transport;

  /// The outer event kinds the recipient wants pushed. `1059` is a NIP-59 gift
  /// wrap, which carries every private notification (live share, DM, …).
  late final _is.ColumnSerializable<List<int>> kinds;

  @override
  List<_is.Column> get columns => [
    id,
    pubKey,
    relay,
    token,
    transport,
    kinds,
  ];
}

class PushSubscriptionInclude extends _is.IncludeObject {
  PushSubscriptionInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => PushSubscription.t;
}

class PushSubscriptionIncludeList extends _is.IncludeList {
  PushSubscriptionIncludeList._({
    _is.WhereExpressionBuilder<PushSubscriptionTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(PushSubscription.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => PushSubscription.t;
}

class PushSubscriptionRepository {
  const PushSubscriptionRepository._();

  /// Returns a list of [PushSubscription]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<PushSubscription>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PushSubscriptionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PushSubscriptionTable>? orderBy,
    _is.OrderByListBuilder<PushSubscriptionTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<PushSubscription>(
      where: where?.call(PushSubscription.t),
      orderBy: orderBy?.call(PushSubscription.t),
      orderByList: orderByList?.call(PushSubscription.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [PushSubscription]s matching the given query parameters every time the
  /// source tables are modified.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// Use [throttle] to specify the minimum interval between queries. It can
  /// also be set to `null`, in which case the stream will only be throttled
  /// when its subscription is paused.
  ///
  /// Source tables are collected from the queried table, [where], [orderBy],
  /// [orderByList], and the [include] graph. [alsoTriggerOnTables] is added
  /// to that set. Pass [Table] instances such as `PushSubscription.t`.
  ///
  /// Raw [Expression] SQL is not inspected. Tables referenced only in raw
  /// SQL must be passed via [alsoTriggerOnTables].
  ///
  /// The stream always reads committed state and never joins an ambient
  /// [Transaction]. Emissions for a write fire after that write commits.
  ///
  /// Currently only supported on SQLite. Calling this method on PostgreSQL
  /// throws an [UnsupportedError].
  ///
  /// ```dart
  /// var subscription = Persons.db.watch(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// ).listen((persons) {
  ///   // Handle the latest matching rows.
  /// });
  /// ```
  _ida.Stream<List<PushSubscription>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PushSubscriptionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PushSubscriptionTable>? orderBy,
    _is.OrderByListBuilder<PushSubscriptionTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<PushSubscription>(
      where: where?.call(PushSubscription.t),
      orderBy: orderBy?.call(PushSubscription.t),
      orderByList: orderByList?.call(PushSubscription.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [PushSubscription] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<PushSubscription?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PushSubscriptionTable>? where,
    int? offset,
    _is.OrderByBuilder<PushSubscriptionTable>? orderBy,
    _is.OrderByListBuilder<PushSubscriptionTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<PushSubscription>(
      where: where?.call(PushSubscription.t),
      orderBy: orderBy?.call(PushSubscription.t),
      orderByList: orderByList?.call(PushSubscription.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [PushSubscription] by its [id] or null if no such row exists.
  Future<PushSubscription?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<PushSubscription>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [PushSubscription]s in the list and returns the inserted rows.
  ///
  /// The returned [PushSubscription]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  ///
  /// If [noReturn] is set to `true`, the inserted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PushSubscription>> insert(
    _is.DatabaseSession session,
    List<PushSubscription> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<PushSubscription>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [PushSubscription] and returns the inserted row.
  ///
  /// The returned [PushSubscription] will have its `id` field set.
  Future<PushSubscription> insertRow(
    _is.DatabaseSession session,
    PushSubscription row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<PushSubscription>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [PushSubscription]s in the list and returns the resulting rows.
  ///
  /// If a row conflicts on the given [conflictColumns], the existing row is
  /// updated with the new values. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies to rows matching the
  /// given expression. Conflicting rows that don't match are skipped and not
  /// returned, so the resulting list may be shorter than [rows].
  ///
  /// The returned [PushSubscription]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PushSubscription>> upsert(
    _is.DatabaseSession session,
    List<PushSubscription> rows, {
    required _is.ColumnSelections<PushSubscriptionTable> conflictColumns,
    _is.ColumnSelections<PushSubscriptionTable>? updateColumns,
    _is.WhereExpressionBuilder<PushSubscriptionTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<PushSubscription>(
      rows,
      conflictColumns: conflictColumns(PushSubscription.t),
      updateColumns: updateColumns?.call(PushSubscription.t),
      updateWhere: updateWhere?.call(PushSubscription.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [PushSubscription] and returns the resulting row.
  ///
  /// If the row conflicts on the given [conflictColumns], the existing row is
  /// updated. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies when the existing
  /// row matches the expression. Returns `null` if no row was affected — for
  /// example when [updateWhere] does not match the conflicting row.
  ///
  /// The returned [PushSubscription] will have its `id` field set.
  Future<PushSubscription?> upsertRow(
    _is.DatabaseSession session,
    PushSubscription row, {
    required _is.ColumnSelections<PushSubscriptionTable> conflictColumns,
    _is.ColumnSelections<PushSubscriptionTable>? updateColumns,
    _is.WhereExpressionBuilder<PushSubscriptionTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<PushSubscription>(
      row,
      conflictColumns: conflictColumns(PushSubscription.t),
      updateColumns: updateColumns?.call(PushSubscription.t),
      updateWhere: updateWhere?.call(PushSubscription.t),
      transaction: transaction,
    );
  }

  /// Updates all [PushSubscription]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PushSubscription>> update(
    _is.DatabaseSession session,
    List<PushSubscription> rows, {
    _is.ColumnSelections<PushSubscriptionTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<PushSubscription>(
      rows,
      columns: columns?.call(PushSubscription.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [PushSubscription]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<PushSubscription> updateRow(
    _is.DatabaseSession session,
    PushSubscription row, {
    _is.ColumnSelections<PushSubscriptionTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<PushSubscription>(
      row,
      columns: columns?.call(PushSubscription.t),
      transaction: transaction,
    );
  }

  /// Updates a single [PushSubscription] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<PushSubscription?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<PushSubscriptionUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<PushSubscription>(
      id,
      columnValues: columnValues(PushSubscription.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [PushSubscription]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PushSubscription>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<PushSubscriptionUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<PushSubscriptionTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PushSubscriptionTable>? orderBy,
    _is.OrderByListBuilder<PushSubscriptionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<PushSubscription>(
      columnValues: columnValues(PushSubscription.t.updateTable),
      where: where(PushSubscription.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(PushSubscription.t),
      orderByList: orderByList?.call(PushSubscription.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [PushSubscription]s in the list and returns the deleted rows.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PushSubscription>> delete(
    _is.DatabaseSession session,
    List<PushSubscription> rows, {
    _is.OrderByBuilder<PushSubscriptionTable>? orderBy,
    _is.OrderByListBuilder<PushSubscriptionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<PushSubscription>(
      rows,
      orderBy: orderBy?.call(PushSubscription.t),
      orderByList: orderByList?.call(PushSubscription.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [PushSubscription].
  Future<PushSubscription> deleteRow(
    _is.DatabaseSession session,
    PushSubscription row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<PushSubscription>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PushSubscription>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<PushSubscriptionTable> where,
    _is.OrderByBuilder<PushSubscriptionTable>? orderBy,
    _is.OrderByListBuilder<PushSubscriptionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<PushSubscription>(
      where: where(PushSubscription.t),
      orderBy: orderBy?.call(PushSubscription.t),
      orderByList: orderByList?.call(PushSubscription.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PushSubscriptionTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<PushSubscription>(
      where: where?.call(PushSubscription.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [PushSubscription] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<PushSubscriptionTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<PushSubscription>(
      where: where(PushSubscription.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
