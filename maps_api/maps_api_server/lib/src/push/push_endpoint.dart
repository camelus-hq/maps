import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'push.dart';
import 'push_config.dart';
import 'push_registration.dart';

/// Registers devices for push and reports their state.
///
/// The caller is a Nostr identity, not a Serverpod account: every method takes
/// a **signed Nostr event** ("proof") and the server verifies its BIP-340
/// signature, so the public key in the event is proven and cannot be spoofed.
/// The push token rides in the event's tags (see [PushRegistration]) so the
/// proof covers it.
class PushEndpoint extends Endpoint {
  /// Registers (or refreshes) the subscriptions described by [registrationJson].
  ///
  /// The event is signed by the identity and carries `push-token`, `relay`
  /// (repeated) and optionally `kind`/`push-transport` tags. New relays are
  /// added to the live forwarder immediately. Returns `true` on success.
  Future<bool> register(Session session, String registrationJson) async {
    final PushRegistration registration = await PushRegistration.parse(
      registrationJson,
    );
    await pushRepository.save(session, registration);
    pushService.ensureRelays(registration.relays);
    await pushService.refreshSubscriptions(session: session);
    session.log(
      'Registered ${registration.pubKey} on ${registration.relays.length} '
      'relay(s) via ${registration.transport}',
    );
    return true;
  }

  /// Reports what [proof]'s identity is registered for.
  ///
  /// [proof] is any event signed by the identity (its tags are not read).
  /// Tokens are never returned.
  Future<PushRegistrationState> getState(
    Session session,
    String proof,
  ) async {
    final String pubKey = await PushRegistration.verifyPubKey(proof);
    return PushRegistrationState(
      pubKey: pubKey,
      availableKinds: PushConfig.availableKinds,
      subscriptions: await pushRepository.infoFor(session, pubKey),
    );
  }

  /// Removes [proof]'s registration, or only [token]'s when given.
  ///
  /// [proof] is any event signed by the identity.
  Future<bool> unregister(
    Session session,
    String proof,
    String? token,
  ) async {
    final String pubKey = await PushRegistration.verifyPubKey(proof);
    await pushRepository.deleteSubscription(session, pubKey, token: token);
    await pushService.refreshSubscriptions(session: session);
    session.log(
      'Unregistered push for $pubKey${token == null ? '' : ' ($token)'}',
    );
    return true;
  }
}
