import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/core/theme/app_theme.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/user_profile.dart';
import 'package:openmaps/domain/entities/user_relay_lists.dart';
import 'package:openmaps/features/social/screens/edit_profile_screen.dart';
import 'package:openmaps/features/social/screens/edit_relays_screen.dart';
import 'package:openmaps/features/social/screens/sign_in_screen.dart';
import 'package:openmaps/features/social/screens/sign_up_screen.dart';
import 'package:openmaps/state/ports.dart';

/// Goldens for the own-brand account screens (Play UI, no Material widgets).
void main() {
  void setSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    FakeSocialService? service,
  }) async {
    final FakeSocialService social =
        service ?? FakeSocialService(signedIn: false);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[socialServiceProvider.overrideWithValue(social)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light(), home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sign-in screen matches the golden', (WidgetTester tester) async {
    setSurface(tester);
    await pump(tester, const SignInView());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/sign_in.png'),
    );
  });

  testWidgets('sign-up step 1 matches the golden', (WidgetTester tester) async {
    setSurface(tester);
    await pump(tester, const SignUpScreen());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/sign_up.png'),
    );
  });

  testWidgets('edit profile matches the golden', (WidgetTester tester) async {
    setSurface(tester);
    await pump(
      tester,
      const EditProfileScreen(),
      service: FakeSocialService()
        ..profile = const UserProfile(
          name: 'Ada Lovelace',
          about: 'Mathematician. Bridges the map and the machine.',
        ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/edit_profile.png'),
    );
  });

  testWidgets('edit relays matches the golden', (WidgetTester tester) async {
    setSurface(tester);
    await pump(
      tester,
      const EditRelaysScreen(),
      service: FakeSocialService()
        ..relays = const UserRelays(
          nip65: <String>['wss://relay.map.camelus.app'],
          dm: <String>['wss://relay.map.camelus.app'],
        ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/edit_relays.png'),
    );
  });
}
