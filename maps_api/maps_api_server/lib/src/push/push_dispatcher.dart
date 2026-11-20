import 'package:ndk/ndk.dart' as ndk;
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'push_config.dart';
import 'push_presence.dart';
import 'push_repository.dart';
import 'push_sender.dart';

/// Turns one relay event into push messages for the identity it is addressed to.
///
/// This is the heart of the forwarder:
///
/// 1. The recipient is the **last `p` tag** of the event (NIP-59 gift wraps
///    carry exactly one, the recipient).
/// 2. An event is only forwarded when the recipient registered for its outer
///    kind — so the server never sprays unrequested notifications.
/// 3. A gift wrap (`1059`) is forwarded **as-is**: the server cannot read it,
///    and neither can FCM. Any other supported kind is gift-wrapped by the
///    server first, so the transport still only carries ciphertext. The
///    ephemeral gift wrap (`21059`) is never forwarded at all — it is a live
///    position update, not a notification (see [PushConfig.ephemeralGiftWrapKind]).
/// 4. The wrapped payload goes to every token the recipient registered, on the
///    transport that token declares. Dead tokens are deleted.
class PushDispatcher {
  const PushDispatcher({
    required this.repository,
    required this.senders,
    required this.presence,
  });

  final PushRepository repository;
  final PushSenderRegistry senders;

  /// Which identities are connected (foreground) and must not be pushed to.
  final PushPresence presence;

  /// Forwards [event] to its recipient, if the recipient asked for it.
  Future<void> dispatch(Session session, ndk.Nip01Event event) async {
    session.log('Dispatching push for event ${event.id} (kind ${event.kind})');

    // An ephemeral gift wrap (21059) is a live-share **position update**:
    // relays do not store it, it goes stale immediately, and the volume is
    // high. The server never forwards it — the app reads it on its own live
    // subscription while it is in the foreground.
    if (event.kind == PushConfig.ephemeralGiftWrapKind) {
      return;
    }
    final List<String> recipients = <String>[
      for (final List<String> tag in event.tags)
        if (tag.length >= 2 && tag[0] == 'p' && tag[1].trim().isNotEmpty)
          tag[1].trim().toLowerCase(),
    ];
    if (recipients.isEmpty) {
      return;
    }
    // A "hellthread" (an event mentioning very many people) is not a
    // notification; pushing it would fan out to everyone.
    if (recipients.length > PushConfig.maxPubkeyPerEvent) {
      return;
    }
    final String recipient = recipients.last;

    // The app has its own relay subscription while it is in the foreground, so
    // it already has this gift wrap. Forwarding would only duplicate it.
    if (presence.isActive(recipient)) {
      session.log('Skipping push for $recipient: client is connected');
      return;
    }

    final List<int> kinds = await repository.kindsFor(session, recipient);
    if (!kinds.contains(event.kind)) {
      return;
    }

    final List<PushSubscription> subscriptions = await repository
        .subscriptionsFor(session, recipient);
    if (subscriptions.isEmpty) {
      return;
    }

    final String payload = await _payloadFor(event, recipient);

    for (final PushSubscription subscription in subscriptions) {
      final PushSender? sender = senders.forTransport(subscription.transport);
      if (sender == null) {
        session.log(
          'No sender for transport "${subscription.transport}" '
          '(token ${_mask(subscription.token)})',
          level: LogLevel.error,
        );
        continue;
      }
      final PushSendResult result = await sender.send(
        subscription.token,
        payload,
      );
      if (result.invalidToken) {
        await repository.deleteToken(session, subscription.token);
        session.log(
          'Deleted dead ${subscription.transport} token '
          '${_mask(subscription.token)}',
        );
      } else if (!result.ok) {
        session.log(
          '${subscription.transport} push failed for '
          '${_mask(subscription.token)}: ${result.error}',
          level: LogLevel.error,
        );
      }
    }
  }

  /// The wire payload: a gift wrap, always.
  Future<String> _payloadFor(ndk.Nip01Event event, String recipient) async {
    if (event.kind == ndk.GiftWrap.kGiftWrapEventkind) {
      return ndk.Nip01EventModel.fromEntity(event).toJsonString();
    }
    final ndk.Nip01Event wrapped = await ndk.GiftWrap.wrapEvent(
      recipientPublicKey: recipient,
      sealEvent: event,
      eventSignerFactory: const ndk.Bip340EventSignerFactory(),
    );
    return ndk.Nip01EventModel.fromEntity(wrapped).toJsonString();
  }

  static String _mask(String token) =>
      token.length <= 10 ? '…' : '${token.substring(0, 6)}…';
}
