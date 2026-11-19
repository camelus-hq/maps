import 'dart:convert';

import '../nostr/live_location_payload.dart';

/// The notification to show for one **decrypted** push event.
///
/// This is the device-side half of the server's forwarder: the server only ever
/// sends a gift wrap, and this maps the rumor inside it to a user-visible
/// notification — but **only** for kinds the app understands. Anything else
/// (a "generic message") is deliberately ignored, so a relay cannot make the
/// app pop an arbitrary alert.
///
/// Pure and hostile-safe: a malformed or unknown event yields `null`.
class PushNotificationContent {
  const PushNotificationContent({
    required this.id,
    required this.title,
    required this.body,
    this.payload,
  });

  /// A stable id so updates from the same sender collapse onto one notice.
  final int id;

  final String title;
  final String body;

  /// JSON handed back to the app when the notification is tapped.
  final String? payload;

  /// NIP-17 direct message (kind 14 inside the wrap).
  static const int directMessageKind = 14;

  /// Maps a decrypted rumor to a notification, or `null` for a kind the app
  /// does not surface.
  static PushNotificationContent? fromDecryptedEvent({
    required int kind,
    required String content,
    required String senderPubkey,
    String? senderName,
  }) {
    if (kind == LiveLocationPayload.rumorKind) {
      final LiveLocationPayload? share = LiveLocationPayload.decode(content);
      // Only the **start** of a session is a notification: a stream of position
      // updates would otherwise spam the recipient (a stop, an unreadable
      // payload or an update is not worth waking the phone for).
      if (share == null ||
          !share.isStart ||
          share.isStop ||
          share.position == null) {
        return null;
      }
      return PushNotificationContent(
        id: _id(senderPubkey, kind, share.sessionId),
        title: _displayName(share.displayName, senderName, senderPubkey),
        body: 'is sharing their location with you',
        payload: jsonEncode(<String, Object?>{
          'kind': kind,
          'route': '/friends',
          'pubkey': senderPubkey,
          'session': share.sessionId,
        }),
      );
    }

    if (kind == directMessageKind) {
      final String text = _truncate(content.trim(), 240);
      if (text.isEmpty) {
        return null;
      }
      return PushNotificationContent(
        id: _id(senderPubkey, kind, null),
        title: _displayName(null, senderName, senderPubkey),
        body: text,
        payload: jsonEncode(<String, Object?>{
          'kind': kind,
          'route': '/messages/$senderPubkey',
          'pubkey': senderPubkey,
        }),
      );
    }

    return null;
  }

  static String _displayName(
    String? fromPayload,
    String? fromProfile,
    String pubkey,
  ) {
    for (final String? candidate in <String?>[fromPayload, fromProfile]) {
      final String trimmed = candidate?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        return trimmed.length > 40 ? '${trimmed.substring(0, 40)}…' : trimmed;
      }
    }
    return _shortKey(pubkey);
  }

  static String _shortKey(String pubkey) => pubkey.length <= 14
      ? pubkey
      : '${pubkey.substring(0, 8)}…${pubkey.substring(pubkey.length - 4)}';

  /// A stable id so re-posts about the same sender/session collapse onto one
  /// notice instead of stacking.
  static int _id(String pubkey, int kind, String? sessionId) =>
      Object.hash(pubkey, kind, sessionId) & 0x7fffffff;

  static String _truncate(String value, int max) =>
      value.length <= max ? value : '${value.substring(0, max - 1)}…';
}
