import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/user_profile.dart';
import 'package:openmaps/domain/entities/user_relay_lists.dart';
import 'package:openmaps/features/social/screens/edit_profile_screen.dart';
import 'package:openmaps/features/social/screens/edit_relays_screen.dart';
import 'package:openmaps/state/ports.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    FakeSocialService? service,
  }) async {
    final FakeSocialService social = service ?? FakeSocialService();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[socialServiceProvider.overrideWithValue(social)],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('edit profile loads the published fields', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      const EditProfileScreen(),
      service: FakeSocialService()
        ..profile = const UserProfile(name: 'Ada', about: 'Pioneer'),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Pioneer'), findsOneWidget);
    // The public-information notice is present.
    expect(find.textContaining('are public'), findsOneWidget);
  });

  testWidgets('edit relays lists both relay lists', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      const EditRelaysScreen(),
      service: FakeSocialService()
        ..relays = const UserRelays(
          nip65: <String>['wss://a.example'],
          dm: <String>['wss://b.example'],
        ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('wss://a.example'), findsOneWidget);
    expect(find.text('wss://b.example'), findsOneWidget);
    expect(find.text('Save relays'), findsOneWidget);
  });

  testWidgets('edit relays prefills a default for an empty list', (
    WidgetTester tester,
  ) async {
    await pump(tester, const EditRelaysScreen());
    // The fake has no relays, so the form starts from the app default.
    expect(find.textContaining('relay.map.camelus.app'), findsWidgets);
  });
}
