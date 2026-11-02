import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/friend.dart';
import 'package:openmaps/domain/entities/friend_location.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/features/social/screens/friends_screen.dart';
import 'package:openmaps/state/ports.dart';

void main() {
  FriendLocation live(Friend friend, {bool ended = false}) {
    final DateTime now = DateTime.now();
    return FriendLocation(
      pubkey: friend.pubkey,
      position: const LatLon(52.5205, 13.4095),
      updatedAt: now,
      expiresAt: now.add(const Duration(minutes: 30)),
      displayName: friend.displayName,
      ended: ended,
    );
  }

  testWidgets('friends screen lists friends and live status', (
    WidgetTester tester,
  ) async {
    final FakeSocialService social = FakeSocialService();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[socialServiceProvider.overrideWithValue(social)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: FriendsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('ALL FRIENDS'), findsOneWidget);
    expect(find.text('LIVE NOW'), findsNothing);
    expect(find.text('Mira'), findsOneWidget);
    expect(find.text('Share live location'), findsOneWidget);

    // A friend starting to share moves under LIVE NOW with a distance.
    final Friend mira = FakeSocialService.demoFriends.first;
    social.emit(live(mira));
    await tester.pumpAndSettle();

    expect(find.text('LIVE NOW'), findsOneWidget);
    expect(find.textContaining('Live ·'), findsOneWidget);

    // The share button opens the share sheet.
    await tester.tap(find.text('Share live location'));
    await tester.pumpAndSettle();
    expect(find.text('Let friends find you'), findsOneWidget);
    Navigator.of(tester.element(find.text('Let friends find you'))).pop();
    await tester.pumpAndSettle();

    // Ending the share drops the row (and cancels the prune timer).
    social.emit(live(mira, ended: true));
    await tester.pumpAndSettle();
    expect(find.text('LIVE NOW'), findsNothing);
  });

  testWidgets('an empty friends list points at the manage screen', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        socialServiceProvider.overrideWithValue(
          FakeSocialService(friends: const <Friend>[]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: FriendsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No friends yet'), findsOneWidget);
    expect(find.text('Add friends'), findsOneWidget);
    // Nothing is copied in from the follow list automatically.
    expect(find.text('Robin'), findsNothing);
  });

  testWidgets('a signed-out visitor is asked to sign in', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        socialServiceProvider.overrideWithValue(
          FakeSocialService(signedIn: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: FriendsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('See where your friends are'), findsOneWidget);
    expect(find.text('Sign in with Nostr'), findsOneWidget);
    expect(find.text('Mira'), findsNothing);
  });
}
