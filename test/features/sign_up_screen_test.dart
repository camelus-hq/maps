import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/features/social/screens/sign_up_screen.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/social.dart';

void main() {
  Future<FakeSocialService> pumpSignUp(WidgetTester tester) async {
    final FakeSocialService social = FakeSocialService(signedIn: false);
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
        child: const MaterialApp(home: SignUpScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return social;
  }

  testWidgets('walks identity → profile → relays → done', (
    WidgetTester tester,
  ) async {
    final FakeSocialService social = await pumpSignUp(tester);

    expect(find.text('Create a new Nostr identity'), findsOneWidget);
    await tester.tap(find.text('Create my identity'));
    await tester.pumpAndSettle();

    // The created key is revealed for backup.
    expect(social.createAccountCalls, 1);
    expect(find.text('Save your private key'), findsOneWidget);
    expect(find.text('nsec1demo'), findsOneWidget);

    await tester.tap(find.text('I saved my key — continue'));
    await tester.pumpAndSettle();
    expect(find.text('Your profile'), findsOneWidget);

    // Skipping the profile goes straight to relays.
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(find.text('Your relays'), findsOneWidget);
    expect(find.text(defaultNostrRelay), findsWidgets);

    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(find.text('You are all set'), findsOneWidget);
    expect(social.relays.nip65, <String>[defaultNostrRelay]);
    expect(social.relays.dm, <String>[defaultNostrRelay]);
  });

  testWidgets('saving the profile publishes it', (WidgetTester tester) async {
    final FakeSocialService social = await pumpSignUp(tester);

    await tester.tap(find.text('Create my identity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I saved my key — continue'));
    await tester.pumpAndSettle();

    // Fill in the name (the first editable text is the name field).
    await tester.enterText(find.byType(EditableText).first, 'Ada');
    await tester.tap(find.text('Save and continue'));
    await tester.pumpAndSettle();

    expect(social.profile.name, 'Ada');
    expect(find.text('Your relays'), findsOneWidget);
  });
}
