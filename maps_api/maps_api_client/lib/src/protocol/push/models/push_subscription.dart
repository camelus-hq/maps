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
import 'package:maps_api_client/src/protocol/protocol.dart' as _i7tlom6q;
import 'package:serverpod_client/serverpod_client.dart' as _isc;

/// One push destination for one Nostr identity on one relay.
///
/// A user can have several rows: one per (relay, token) pair, so they can be
/// reached on any of their relays and from any of their devices. The token is
/// either an FCM registration token (Firebase transport) or a UnifiedPush
/// endpoint URL; `transport` records which, so the forwarder knows how to send.
abstract class PushSubscription
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
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
          : _i7tlom6q.Protocol().deserialize<List<int>>(
              jsonSerialization['kinds'],
            ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
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

  /// Returns a shallow copy of this [PushSubscription]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  PushSubscription copyWith({
    int? id,
    String? pubKey,
    String? relay,
    String? token,
    String? transport,
    List<int>? kinds = const _isc.$UndefinedList<int>(),
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

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
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
  @_isc.useResult
  @override
  PushSubscription copyWith({
    Object? id = _Undefined,
    String? pubKey,
    String? relay,
    String? token,
    String? transport,
    List<int>? kinds = const _isc.$UndefinedList<int>(),
  }) {
    return PushSubscription(
      id: id is int? ? id : this.id,
      pubKey: pubKey ?? this.pubKey,
      relay: relay ?? this.relay,
      token: token ?? this.token,
      transport: transport ?? this.transport,
      kinds: kinds is _isc.UndefinedSentinel
          ? this.kinds?.map((e0) => e0).toList()
          : kinds,
    );
  }
}
