import 'fcm_sender.dart';
import 'push_dispatcher.dart';
import 'push_presence.dart';
import 'push_repository.dart';
import 'push_sender.dart';
import 'push_service.dart';

/// Composition root for the push stack.
///
/// One repository, one sender registry (Firebase + UnifiedPush), one dispatcher
/// and one long-lived [pushService]. The endpoint writes registrations through
/// [pushRepository] and tells [pushService] about new relays; the forwarder
/// reads registrations and dispatches through [pushDispatcher].
const PushRepository pushRepository = PushRepository();

/// Which identities currently have a live foreground connection to this server.
final PushPresence pushPresence = PushPresence();

final PushSenderRegistry pushSenders = PushSenderRegistry(<PushSender>[
  // Firebase Cloud Messaging is the default transport.
  FcmSender(),
  // UnifiedPush (ntfy and compatible distributors) for users who opt out of
  // Google services. The choice is encoded in the token: FCM tokens are not
  // URLs, UnifiedPush endpoints are.
  UnifiedPushSender(),
]);

final PushDispatcher pushDispatcher = PushDispatcher(
  repository: pushRepository,
  senders: pushSenders,
  presence: pushPresence,
);

final PushService pushService = PushService(
  repository: pushRepository,
  dispatcher: pushDispatcher,
);
