import '../entities/friend_location.dart';
import '../ports/social_service.dart';

/// Streams friends' live locations through [SocialService].
class WatchFriendLocations {
  const WatchFriendLocations(this._socialService);

  final SocialService _socialService;

  Stream<FriendLocation> call() => _socialService.watchFriendLocations();
}
