import '../entities/friend.dart';
import '../ports/social_service.dart';

/// Loads the signed-in user's friends (Nostr contact list) through
/// [SocialService].
class LoadFriends {
  const LoadFriends(this._socialService);

  final SocialService _socialService;

  Future<List<Friend>> call() => _socialService.loadFriends();
}
