import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';
import 'package:serverpod_cloud_storage/serverpod_cloud_storage.dart';

import 'src/generated/serverpod.dart';
import 'src/push/push.dart';

/// The starting point of the Serverpod server.
///
/// This is a **backend only** (there is no companion Flutter app in this
/// workspace; the OpenMaps app talks to it through the generated client). Its
/// job is the Nostr push forwarder.
void run(List<String> args) async {
  final pod = Serverpod(args);

  // Serverpod's built-in authentication (email/password + JWT). The push
  // endpoints themselves are authenticated by the caller's Nostr signature, not
  // a Serverpod account, so this stays available for future account features.
  pod.initializeAuthServices(
    tokenManagerBuilders: <TokenManagerBuilder>[
      JwtConfigFromPasswords(),
    ],
    identityProviderBuilders: <IdentityProviderBuilder>[
      ServerpodCloudEmailIdpConfig(appDisplayName: 'maps_api'),
    ],
  );

  // Configure cloud storage. This setup works with Serverpod Cloud without
  // extra configuration.
  pod.addCloudStorage(
    await ServerpodCloudProvider.private(
      fallback: () => DatabaseCloudStorage('private'),
    ),
  );
  pod.addCloudStorage(
    await ServerpodCloudProvider.public(
      fallback: () => DatabaseCloudStorage('public'),
    ),
  );

  // Start the server.
  await pod.start();

  // Start the Nostr push forwarder: it watches relays for gift wraps addressed
  // to registered identities and forwards them (still encrypted) through FCM or
  // UnifiedPush. Started after `pod.start()` so `Serverpod.instance` exists for
  // the forwarder's own database sessions.
  await pushService.start(pod: pod);
}
