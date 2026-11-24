import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/features/social/screens/sign_in_screen.dart';
import 'package:openmaps/state/ports.dart';

void main() {
  Future<FakeSocialService> pumpSignIn(
    WidgetTester tester, {
    FakeSocialService? service,
  }) async {
    final FakeSocialService social =
        service ?? FakeSocialService(signedIn: false);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[socialServiceProvider.overrideWithValue(social)],
    );
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // No GoRouter: SignInView never navigates on this screen itself.
        child: const MaterialApp(home: SignInView()),
      ),
    );
    await tester.pumpAndSettle();
    return social;
  }

  testWidgets('offers the signer app, bunker and private-key paths', (
    WidgetTester tester,
  ) async {
    await pumpSignIn(tester);

    expect(find.text('Sign in with a signer app'), findsOneWidget);
    expect(find.text('Connect with a bunker'), findsOneWidget);
    expect(find.text('Sign in with a private key'), findsOneWidget);
    expect(find.text('Create a new identity'), findsOneWidget);
  });

  testWidgets('the signer app button signs in', (WidgetTester tester) async {
    final FakeSocialService social = await pumpSignIn(tester);

    await tester.tap(find.text('Sign in with a signer app'));
    await tester.pumpAndSettle();

    expect(social.signedInWithSignerApp, isTrue);
  });

  testWidgets('a private key signs in without a Material ancestor', (
    WidgetTester tester,
  ) async {
    final FakeSocialService social = await pumpSignIn(tester);

    await tester.enterText(find.byType(EditableText).at(1), 'nsec1demo');
    await tester.tap(find.text('Sign in with a private key'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(social.signedInWithKey, 'nsec1demo');
  });

  testWidgets('an invalid bunker URL shows an inline error', (
    WidgetTester tester,
  ) async {
    await pumpSignIn(tester);

    await tester.enterText(find.byType(EditableText).first, 'not-a-bunker');
    await tester.tap(find.text('Connect with a bunker'));
    await tester.pumpAndSettle();

    expect(find.textContaining('bunker://'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides the signer-app path when the platform has none', (
    WidgetTester tester,
  ) async {
    await pumpSignIn(
      tester,
      service: FakeSocialService(signedIn: false)..supportsSignerApp = false,
    );

    expect(find.text('Sign in with a signer app'), findsNothing);
    expect(find.text('Sign in with a private key'), findsOneWidget);
  });
}
