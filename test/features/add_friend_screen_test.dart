import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/friend.dart';
import 'package:openmaps/features/social/screens/add_friend_screen.dart';
import 'package:openmaps/features/social/widgets/qr_code_view.dart';
import 'package:openmaps/state/ports.dart';

void main() {
  const String other =
      'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

  Future<FakeSocialService> pumpAddFriend(
    WidgetTester tester, {
    bool signedIn = true,
  }) async {
    final FakeSocialService social = FakeSocialService(
      friends: const <Friend>[],
      signedIn: signedIn,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[socialServiceProvider.overrideWithValue(social)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AddFriendScreen(
            cameraBuilder: (BuildContext context, void Function(String) scan) {
              return Center(
                child: ElevatedButton(
                  onPressed: () => scan(other),
                  child: const Text('stub-scan'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return social;
  }

  testWidgets('shows a tab bar with My code first', (
    WidgetTester tester,
  ) async {
    await pumpAddFriend(tester);

    expect(find.text('Add friend'), findsOneWidget);
    expect(find.text('My code'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
  });

  testWidgets('My code shows the profile and a QR of the npub', (
    WidgetTester tester,
  ) async {
    final FakeSocialService social = await pumpAddFriend(tester);

    final String? me = social.currentUserPubkey;
    expect(me, isNotNull);
    final String npub = social.encodeNpub(me!)!;

    expect(find.byType(QrCodeView), findsOneWidget);
    final QrCodeView qr = tester.widget<QrCodeView>(find.byType(QrCodeView));
    expect(qr.data, npub);
    expect(npub.startsWith('npub1'), isTrue);

    // The profile line and the copyable key are on screen.
    expect(find.text('Let a friend scan this to add you'), findsOneWidget);
    expect(find.textContaining(npub), findsOneWidget);
    expect(find.text('Copy my public key'), findsOneWidget);
    // The fake's placeholder npub is not decodable; the real bech32 round trip
    // is covered by test/data/nostr_npub_codec_test.dart.
  });

  testWidgets('My code asks a signed-out visitor to sign in', (
    WidgetTester tester,
  ) async {
    await pumpAddFriend(tester, signedIn: false);

    expect(find.text('Sign in to show your code'), findsOneWidget);
    expect(find.byType(QrCodeView), findsNothing);
  });

  testWidgets('the Scan tab adds a scanned npub', (WidgetTester tester) async {
    final FakeSocialService social = await pumpAddFriend(tester);

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.text('stub-scan'), findsOneWidget);
    await tester.tap(find.text('stub-scan'));
    await tester.pumpAndSettle();

    expect(await social.loadFriends(), hasLength(1));
  });

  testWidgets('the Scan tab adds a pasted key', (WidgetTester tester) async {
    final FakeSocialService social = await pumpAddFriend(tester);

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), ' nostr:$other ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add this friend'));
    await tester.pumpAndSettle();

    expect(await social.loadFriends(), hasLength(1));
  });

  testWidgets('garbage input shows an inline error and adds nobody', (
    WidgetTester tester,
  ) async {
    final FakeSocialService social = await pumpAddFriend(tester);

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'not-a-key');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add this friend'));
    await tester.pumpAndSettle();

    expect(
      find.text('That is not a Nostr public key (npub… or 64 hex characters).'),
      findsOneWidget,
    );
    expect(await social.loadFriends(), isEmpty);
  });

  testWidgets('an empty submit explains what is needed', (
    WidgetTester tester,
  ) async {
    final FakeSocialService social = await pumpAddFriend(tester);

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add this friend'));
    await tester.pumpAndSettle();

    expect(find.text('Scan or paste a Nostr public key.'), findsOneWidget);
    expect(await social.loadFriends(), isEmpty);
  });
}
