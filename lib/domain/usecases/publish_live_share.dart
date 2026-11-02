import '../../core/errors/app_exception.dart';
import '../entities/live_share.dart';
import '../ports/social_service.dart';

/// Validates and publishes one live-location broadcast to the selected friends.
///
/// The recipient list is normalised here (trimmed, lowercase, de-duplicated and
/// bounded) so a hostile or sloppy caller can never fan a share out to an
/// unbounded set of keys or an invalid wire address.
class PublishLiveShare {
  const PublishLiveShare(this._socialService);

  final SocialService _socialService;

  /// Hard cap on how many friends one share may address.
  static const int maxRecipients = 200;

  static final RegExp _hexPubkey = RegExp(r'^[0-9a-f]{64}$');

  Future<void> call({
    required LiveShareBroadcast broadcast,
    required List<String> recipientPubkeys,
  }) async {
    if (broadcast.sessionId.trim().isEmpty) {
      throw const ValidationException('Live share has no session id');
    }
    if (broadcast.kind == LiveShareBroadcastKind.update &&
        broadcast.position == null) {
      throw const ValidationException('Live share update has no position');
    }
    final List<String> recipients = <String>[];
    for (final String raw in recipientPubkeys) {
      final String pubkey = raw.trim().toLowerCase();
      if (!_hexPubkey.hasMatch(pubkey) || recipients.contains(pubkey)) {
        continue;
      }
      recipients.add(pubkey);
      if (recipients.length >= maxRecipients) {
        break;
      }
    }
    if (recipients.isEmpty) {
      throw const ValidationException(
        'Select at least one friend to share with',
      );
    }
    await _socialService.publishLiveShare(
      broadcast: broadcast,
      recipientPubkeys: recipients,
    );
  }
}
