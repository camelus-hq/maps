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

/// A relay a Nostr identity is registered on, with the outer kinds requested
/// for it. Returned by `PushEndpoint.getState`; carries no token.
abstract class PushSubscriptionInfo
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PushSubscriptionInfo._({
    required this.relay,
    required this.kinds,
  });

  factory PushSubscriptionInfo({
    required String relay,
    required List<int> kinds,
  }) = _PushSubscriptionInfoImpl;

  factory PushSubscriptionInfo.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PushSubscriptionInfo(
      relay: jsonSerialization['relay'] as String,
      kinds: _i7tlom6q.Protocol().deserialize<List<int>>(
        jsonSerialization['kinds'],
      ),
    );
  }

  /// The relay URL the identity can be reached on.
  String relay;

  /// The outer event kinds requested for this relay.
  List<int> kinds;

  /// Returns a shallow copy of this [PushSubscriptionInfo]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  PushSubscriptionInfo copyWith({
    String? relay,
    List<int>? kinds,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PushSubscriptionInfo',
      'relay': relay,
      'kinds': kinds.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PushSubscriptionInfo',
      'relay': relay,
      'kinds': kinds.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _PushSubscriptionInfoImpl extends PushSubscriptionInfo {
  _PushSubscriptionInfoImpl({
    required String relay,
    required List<int> kinds,
  }) : super._(
         relay: relay,
         kinds: kinds,
       );

  /// Returns a shallow copy of this [PushSubscriptionInfo]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PushSubscriptionInfo copyWith({
    String? relay,
    List<int>? kinds,
  }) {
    return PushSubscriptionInfo(
      relay: relay ?? this.relay,
      kinds: kinds ?? this.kinds.map((e0) => e0).toList(),
    );
  }
}
