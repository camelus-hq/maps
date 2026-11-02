import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/friend.dart';
import 'package:openmaps/features/social/screens/manage_friends_screen.dart';
import 'package:openmaps/state/ports.dart';

void main() {
  Future<FakeSocialService> pumpManage(
    WidgetTester tester, {
    List<Friend>? friends,
  }) async {
    final FakeSocialService social = FakeSocialService(friends: friends);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[socialServiceProvider.overrideWithValue(social)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ManageFriendsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return social;
  }

  testWidgets('lists friends and removes one after confirmation', (
    WidgetTester tester,
  ) async {
    final FakeSocialService social = await pumpManage(tester);

    expect(find.text('Manage friends'), findsOneWidget);
    expect(find.text('Mira'), findsOneWidget);
    expect(await social.loadFriends(), hasLength(4));

    await tester.tap(find.byTooltip('Remove').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Remove '), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    final List<Friend> left = await social.loadFriends();
    expect(left, hasLength(3));
    expect(left.any((Friend friend) => friend.displayName == 'Mira'), isFalse);
  });

  testWidgets('adds a friend from the people you follow', (
    WidgetTester tester,
  ) async {
    final FakeSocialService social = await pumpManage(
      tester,
      friends: const <Friend>[],
    );

    expect(find.text('No friends yet'), findsOneWidget);

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(find.text('Robin'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);
    expect(await social.loadFriends(), isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Add').first);
    await tester.pumpAndSettle();

    final List<Friend> friends = await social.loadFriends();
    expect(friends, hasLength(1));
    // The other following was not copied in.
    expect(find.text('Added'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('the following list can be filtered', (
    WidgetTester tester,
  ) async {
    await pumpManage(tester, friends: const <Friend>[]);

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'rob');
    await tester.pumpAndSettle();
    expect(find.text('Robin'), findsOneWidget);
    expect(find.text('Sam'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
  });

  testWidgets('a signed-out user is asked to sign in', (
    WidgetTester tester,
  ) async {
    await pumpManage(tester, friends: const <Friend>[]);
    // Re-pump with a signed-out service to cover that branch.
    final FakeSocialService social = FakeSocialService(signedIn: false);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[socialServiceProvider.overrideWithValue(social)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ManageFriendsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Sign in with Nostr to manage your friends.'),
      findsOneWidget,
    );
    expect(find.text('Add friend'), findsNothing);
  });
}
