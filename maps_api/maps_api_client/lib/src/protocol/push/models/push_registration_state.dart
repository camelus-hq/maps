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
import '../../push/models/push_subscription_info.dart' as _iz724rgj;

/// The push destinations registered for one Nostr identity, as reported back
/// to the client. Tokens are never echoed back.
abstract class PushRegistrationState
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PushRegistrationState._({
    required this.pubKey,
    required this.availableKinds,
    required this.subscriptions,
  });

  factory PushRegistrationState({
    required String pubKey,
    required List<int> availableKinds,
    required List<_iz724rgj.PushSubscriptionInfo> subscriptions,
  }) = _PushRegistrationStateImpl;

  factory PushRegistrationState.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PushRegistrationState(
      pubKey: jsonSerialization['pubKey'] as String,
      availableKinds: _i7tlom6q.Protocol().deserialize<List<int>>(
        jsonSerialization['availableKinds'],
      ),
      subscriptions: _i7tlom6q.Protocol()
          .deserialize<List<_iz724rgj.PushSubscriptionInfo>>(
            jsonSerialization['subscriptions'],
          ),
    );
  }

  /// The Nostr public key these subscriptions belong to.
  String pubKey;

  /// The outer event kinds this server can forward (see `PushConfig`).
  List<int> availableKinds;

  /// One entry per relay the identity is registered on, with its kinds.
  List<_iz724rgj.PushSubscriptionInfo> subscriptions;

  /// Returns a shallow copy of this [PushRegistrationState]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  PushRegistrationState copyWith({
    String? pubKey,
    List<int>? availableKinds,
    List<_iz724rgj.PushSubscriptionInfo>? subscriptions,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PushRegistrationState',
      'pubKey': pubKey,
      'availableKinds': availableKinds.toJson(),
      'subscriptions': subscriptions.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PushRegistrationState',
      'pubKey': pubKey,
      'availableKinds': availableKinds.toJson(),
      'subscriptions': subscriptions.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _PushRegistrationStateImpl extends PushRegistrationState {
  _PushRegistrationStateImpl({
    required String pubKey,
    required List<int> availableKinds,
    required List<_iz724rgj.PushSubscriptionInfo> subscriptions,
  }) : super._(
         pubKey: pubKey,
         availableKinds: availableKinds,
         subscriptions: subscriptions,
       );

  /// Returns a shallow copy of this [PushRegistrationState]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PushRegistrationState copyWith({
    String? pubKey,
    List<int>? availableKinds,
    List<_iz724rgj.PushSubscriptionInfo>? subscriptions,
  }) {
    return PushRegistrationState(
      pubKey: pubKey ?? this.pubKey,
      availableKinds:
          availableKinds ?? this.availableKinds.map((e0) => e0).toList(),
      subscriptions:
          subscriptions ??
          this.subscriptions.map((e0) => e0.copyWith()).toList(),
    );
  }
}
