import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/friend.dart';

void main() {
  const String other =
      'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

  test('the fake manages its friends set', () async {
    final FakeSocialService service = FakeSocialService();
    addTearDown(service.dispose);

    expect(await service.loadFriends(), hasLength(4));

    await service.addFriend(other.toUpperCase());
    final List<Friend> afterAdd = await service.loadFriends();
    expect(afterAdd.any((Friend f) => f.pubkey == other), isTrue);

    await service.removeFriend(other);
    final List<Friend> afterRemove = await service.loadFriends();
    expect(afterRemove.any((Friend f) => f.pubkey == other), isFalse);
  });

  test('the fake lists followings without adding them as friends', () async {
    final FakeSocialService service = FakeSocialService();
    addTearDown(service.dispose);

    final List<Friend> followings = await service.loadFollowings();
    expect(followings, hasLength(2));
    expect(await service.loadFriends(), hasLength(4));
    // Followings are offered, never copied in automatically.
    expect(
      (await service.loadFriends()).any(
        (Friend f) => followings.any((Friend o) => o.pubkey == f.pubkey),
      ),
      isFalse,
    );
  });

  test('the fake rejects hostile keys and signed-out writes', () async {
    final FakeSocialService service = FakeSocialService();
    addTearDown(service.dispose);

    await expectLater(
      service.addFriend('nope'),
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      service.removeFriend(''),
      throwsA(isA<ValidationException>()),
    );

    final FakeSocialService signedOut = FakeSocialService(signedIn: false);
    addTearDown(signedOut.dispose);
    await expectLater(
      signedOut.addFriend(other),
      throwsA(isA<ValidationException>()),
    );
    expect(await signedOut.loadFriends(), isEmpty);
    expect(await signedOut.loadFollowings(), isEmpty);
  });

  test('the fake resolves a profile for an unknown key', () async {
    final FakeSocialService service = FakeSocialService();
    addTearDown(service.dispose);

    final Friend known = await service.resolveProfile(other);
    expect(known.pubkey, other);
    expect(known.displayName, isNotEmpty);

    await expectLater(
      service.resolveProfile('nope'),
      throwsA(isA<ValidationException>()),
    );
  });

  test('the fake normalises pasted keys', () async {
    final FakeSocialService service = FakeSocialService();
    addTearDown(service.dispose);

    expect(service.normalizePubkey(other.toUpperCase()), other);
    expect(service.normalizePubkey(' nostr:$other '), other);
    expect(service.normalizePubkey('npub1nope'), isNull);
    expect(service.normalizePubkey(''), isNull);
    expect(service.normalizePubkey('x' * 64), isNull);
  });
}
