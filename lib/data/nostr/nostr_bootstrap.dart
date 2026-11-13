import 'package:ndk/ndk.dart';
import 'package:ndk_flutter/ndk_flutter.dart';

/// Builds the NDK client and its Flutter widget wrapper.
///
/// Kept in the data layer so nothing else has to know how the Nostr client is
/// configured; `lib/app/di.dart` calls this once at bootstrap.
abstract final class NostrBootstrap {
  /// Creates the shared NDK client (default bootstrap relays, in-memory cache).
  static Ndk createClient() => Ndk(
    NdkConfig(
      cache: MemCacheManager(),
      eventVerifier: Bip340EventVerifier(),
      bootstrapRelays: ['wss://relay.camelus.app', 'wss://nos.lol'],
      logLevel: LogLevel.info,
    ),
  );

  /// Wraps [ndk] for the ndk_flutter widgets (login, profile, avatars).
  static NdkFlutter wrap(Ndk ndk) => NdkFlutter(ndk: ndk);
}
