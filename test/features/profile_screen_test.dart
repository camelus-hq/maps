import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/features/design/play.dart';
import 'package:openmaps/features/social/screens/profile_screen.dart';
import 'package:openmaps/features/social/screens/sign_in_screen.dart';
import 'package:openmaps/state/ports.dart';

void main() {
  Future<FakeSocialService> pumpProfile(
    WidgetTester tester, {
    required bool signedIn,
    FakeSocialService? service,
  }) async {
    final FakeSocialService social =
        service ?? FakeSocialService(signedIn: signedIn);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[socialServiceProvider.overrideWithValue(social)],
    );
    addTearDown(container.dispose);

    // A tall surface keeps the whole (scrollable) form laid out.
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return social;
  }

  testWidgets('signed-out profile shows the Play sign-in form', (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester, signedIn: false);

    expect(tester.takeException(), isNull);
    expect(find.byType(SignInView), findsOneWidget);
    expect(find.text('Sign in to Nostr'), findsOneWidget);
    expect(find.text('Sign in with a signer app'), findsOneWidget);
    expect(find.text('Create a new identity'), findsOneWidget);
    // The old ndk_flutter login is gone.
    expect(find.byType(PlayButton), findsWidgets);
  });

  testWidgets('signed-in profile offers profile, relays and sign out', (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester, signedIn: true);

    expect(tester.takeException(), isNull);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Relays'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });
}
