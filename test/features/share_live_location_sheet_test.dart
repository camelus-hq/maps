import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/data/fakes/fake_live_share_notifications.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/friend.dart';
import 'package:openmaps/features/social/screens/share_live_location_sheet.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/social.dart';

void main() {
  /// The sheet is tall (friend list + duration + consent note); give it a phone
  /// surface large enough that the primary action stays on screen.
  void setSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('the share sheet selects friends and starts a share', (
    WidgetTester tester,
  ) async {
    setSurface(tester);
    final FakeSocialService social = FakeSocialService();
    final FakeLiveShareNotifications notifications =
        FakeLiveShareNotifications();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        socialServiceProvider.overrideWithValue(social),
        liveShareNotificationsProvider.overrideWithValue(notifications),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: ShareLiveLocationSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Let friends find you'), findsOneWidget);
    expect(
      find.text('You choose who sees it and for how long.'),
      findsOneWidget,
    );
    expect(find.text('Mira'), findsOneWidget);
    expect(find.text('Timo'), findsOneWidget);
    expect(find.text('None selected'), findsOneWidget);

    // Nothing selected: the primary action is disabled.
    final Finder action = find.widgetWithText(
      FilledButton,
      'Select friends to share with',
    );
    expect(tester.widget<FilledButton>(action).onPressed, isNull);

    await tester.tap(find.text('Mira'));
    await tester.tap(find.text('Timo'));
    await tester.pumpAndSettle();

    expect(find.text('2 selected'), findsOneWidget);
    expect(find.text('Share live with 2 friends'), findsOneWidget);
    expect(
      find.text('Only Mira and Timo can see your location'),
      findsOneWidget,
    );

    await tester.tap(find.text('Share live with 2 friends'));
    await tester.pumpAndSettle();

    final List<Friend> friends = await container.read(friendsProvider.future);
    final Friend mira = friends.firstWhere(
      (Friend friend) => friend.displayName == 'Mira',
    );
    final Friend timo = friends.firstWhere(
      (Friend friend) => friend.displayName == 'Timo',
    );
    expect(container.read(liveShareProvider).isActive, isTrue);
    expect(container.read(liveShareProvider).recipientCount, 2);
    expect(social.published, hasLength(1));
    expect(
      social.publishedRecipients.single,
      containsAll(<String>[mira.pubkey, timo.pubkey]),
    );
    expect(notifications.visible, isTrue);

    // Stop before the test ends so the share's expiry timer is cancelled.
    await container.read(liveShareProvider.notifier).stop();
    addTearDown(container.dispose);
  });

  testWidgets('the duration choice changes the auto-stop time', (
    WidgetTester tester,
  ) async {
    setSurface(tester);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        socialServiceProvider.overrideWithValue(FakeSocialService()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: ShareLiveLocationSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final String before = tester
        .widget<Text>(find.textContaining('Sharing will stop automatically at'))
        .data!;
    expect(find.text('1 hour'), findsOneWidget);

    await tester.tap(find.text('4 hours'));
    await tester.pumpAndSettle();

    final ChoiceChip fourHours = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '4 hours'),
    );
    expect(fourHours.selected, isTrue);
    final String after = tester
        .widget<Text>(find.textContaining('Sharing will stop automatically at'))
        .data!;
    expect(after, isNot(before));
  });

  testWidgets('a signed-out user is asked to sign in first', (
    WidgetTester tester,
  ) async {
    setSurface(tester);
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
        child: const MaterialApp(
          home: Scaffold(body: ShareLiveLocationSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in to share your location'), findsOneWidget);
    expect(find.text('Sign in with Nostr'), findsOneWidget);
  });
}
