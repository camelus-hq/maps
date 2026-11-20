import 'package:ndk/ndk.dart';

import '../../domain/entities/live_share.dart';

/// The wire-level shape of the live-share gift wraps: which **outer** NIP-59
/// kind carries which broadcast, and the relay filter that receives them.
///
/// Kept free of `ndk_flutter` (and any Flutter import) so the mapping and the
/// subscription filter are unit-testable without pulling in a widget layer.
///
/// A session **start** and **stop** travel in a **stored** gift wrap (kind
/// `1059`) so the push server can forward them to a closed app. The recurring
/// position **updates** travel in an **ephemeral** gift wrap (kind `21059`)
/// that relays must not store and the server never forwards, so they reach only
/// an app that is currently listening.

/// The relay `REQ` filter for the gift wraps addressed to [pubKey].
///
/// Watches **both** gift-wrap kinds: the stored start/stop wraps (kind `1059`)
/// and the ephemeral position updates (kind `21059`).
///
/// **Live-only**: `limit: 0` asks a relay for no stored events, and [since]
/// (seconds, the moment the subscription opened) bounds it, so a relay never
/// replays the gift wraps it already has — an old DM or share would otherwise
/// surface, and raise a notification, on every (re)subscribe or reconnect.
/// `since` is fixed for the life of the subscription, so a reconnect still
/// catches what arrived while the socket was down.
///
/// Exposed (rather than inlined) so the live-only contract has a regression
/// test.
Filter liveLocationFilter(String pubKey, {required int since}) => Filter(
  kinds: <int>[
    GiftWrap.kGiftWrapEventkind,
    GiftWrap.kEphemeralGiftWrapEventKind,
  ],
  pTags: <String>[pubKey],

  /// somehow with since filter it does not work (may be a relay or ndk issue?)
  //since: since,
  limit: 0,
);

/// Whether a live-share broadcast of [kind] is carried by an **ephemeral**
/// gift wrap (`21059`) rather than a stored one (`1059`).
///
/// A session **start** and **stop** are stored wraps, so the push server can
/// forward them while the app is closed. The recurring position **updates** are
/// ephemeral: relays must not store them and the server never forwards them, so
/// they reach only an app that is currently listening.
bool isEphemeralLiveShare(LiveShareBroadcastKind kind) =>
    kind == LiveShareBroadcastKind.update;
