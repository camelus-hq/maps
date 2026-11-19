import 'dart:async';

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

  /// Holds a server connection open on behalf of [proof]'s identity while the
  /// app is in the foreground and receiving gift wraps on its own relay
  /// subscription.
  ///
  /// While this stream is open the forwarder **pauses** pushing to the identity
  /// — the app already has the gift wrap, so a push would only duplicate it.
  /// The stream ends when the app backgrounds (the client cancels it) or the
  /// connection times out (Serverpod pings the websocket every 30 s and closes
  /// a dead one); forwarding then resumes automatically.
  Stream<String> foreground(Session session, String proof) {
    final StreamController<String> controller = StreamController<String>();
    String? pubKey;
    bool added = false;
    bool cancelled = false;

    controller.onListen = () {
      unawaited(() async {
        final String verified;
        try {
          verified = await PushRegistration.verifyPubKey(proof);
        } catch (error) {
          if (!controller.isClosed) {
            controller.addError(error);
            await controller.close();
          }
          return;
        }
        // The client may have disconnected while the signature was verified.
        if (cancelled) {
          return;
        }
        pubKey = verified;
        added = true;
        pushPresence.add(verified);
        session.log('Push paused for $verified (foreground session open)');
        if (!controller.isClosed) {
          controller.add('active');
        }
      }());
    };

    controller.onCancel = () {
      cancelled = true;
      final String? key = pubKey;
      if (added && key != null) {
        pushPresence.remove(key);
      }
    };

    return controller.stream;
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
