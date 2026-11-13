import '../entities/nostr_identity.dart';

/// Supplies the app's persistent, **anonymous** Nostr identity.
///
/// Some features must publish a signed Nostr event without asking the user to
/// have an account. They call [current]: the first call generates a key pair
/// and stores it locally, and every later call — in this run and in every later
/// run of the app — returns the *same* identity, so an anonymous author is
/// stable over time while never being linked to the user.
///
/// This is deliberately separate from a signed-in account: when the user *is*
/// signed in, callers should prefer that account (see `FeedbackService`, which
/// sends as the signed-in user and falls back to this identity otherwise).
/// Nothing here touches the network.
///
/// Implemented in `data/` (the anonymous key pair lives in the local
/// [AppDatabase](app_database.dart)); the keyless/test default is an in-memory
/// fake that still generates a real key pair.
abstract interface class AnonymousIdentity {
  /// The anonymous identity, generating and persisting one on first use.
  ///
  /// Never throws: returns `null` only when no identity can be provided at all,
  /// so a caller degrades gracefully instead of crashing.
  Future<NostrIdentity?> current();
}
