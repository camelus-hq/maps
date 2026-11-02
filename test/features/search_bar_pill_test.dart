import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/features/map_home/widgets/search_bar_pill.dart';
import 'package:openmaps/features/social/widgets/friend_avatar.dart';
import 'package:openmaps/state/ports.dart';

void main() {
  Future<void> pumpPill(WidgetTester tester, ProviderContainer container) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: SearchBarPill(onTap: () {})),
        ),
      ),
    );
  }

  testWidgets('the account slot shows the signed-in profile avatar', (
    WidgetTester tester,
  ) async {
    final FakeSocialService social = FakeSocialService();
    addTearDown(social.dispose);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[socialServiceProvider.overrideWithValue(social)],
    );
    addTearDown(container.dispose);

    await pumpPill(tester, container);
    await tester.pumpAndSettle();

    expect(find.byType(FriendAvatar), findsOneWidget);
    expect(find.byIcon(Icons.person), findsNothing);
  });

  testWidgets('the account slot falls back to a person icon when signed out', (
    WidgetTester tester,
  ) async {
    final FakeSocialService social = FakeSocialService(signedIn: false);
    addTearDown(social.dispose);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[socialServiceProvider.overrideWithValue(social)],
    );
    addTearDown(container.dispose);

    await pumpPill(tester, container);
    await tester.pumpAndSettle();

    expect(find.byType(FriendAvatar), findsNothing);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
