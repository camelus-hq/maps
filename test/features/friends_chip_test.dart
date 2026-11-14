import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/data/fakes/fake_map_service.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/friend_location.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/features/social/widgets/friends_chip.dart';
import 'package:openmaps/state/ports.dart';

void main() {
  testWidgets('tapping the live badge frames every live friend', (
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
        child: const MaterialApp(home: Scaffold(body: FriendsChip())),
      ),
    );
    await tester.pumpAndSettle();

    // Nobody live yet: no badge, nothing to frame.
    expect(find.textContaining('friends live'), findsNothing);

    final DateTime now = DateTime.now();
    for (int i = 0; i < 2; i++) {
      social.emit(
        FriendLocation(
          pubkey: FakeSocialService.demoFriends[i].pubkey,
          position: LatLon(52.5 + i * 0.1, 13.4 + i * 0.1),
          updatedAt: now,
          expiresAt: now.add(const Duration(minutes: 30)),
          displayName: FakeSocialService.demoFriends[i].displayName,
        ),
      );
    }
    await tester.pumpAndSettle();
    expect(find.text('2 friends live'), findsOneWidget);

    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;
    await tester.tap(find.text('2 friends live'));
    await tester.pumpAndSettle();

    // Fitted between the two pins.
    expect(map.camera.target.latitude, closeTo(52.55, 0.05));
    expect(map.camera.target.longitude, closeTo(13.45, 0.05));

    // Ending both shares removes the badge again.
    for (int i = 0; i < 2; i++) {
      social.emit(
        FriendLocation(
          pubkey: FakeSocialService.demoFriends[i].pubkey,
          updatedAt: now,
          expiresAt: now.add(const Duration(minutes: 30)),
          ended: true,
        ),
      );
    }
    await tester.pumpAndSettle();
    expect(find.textContaining('friends live'), findsNothing);
  });
}
