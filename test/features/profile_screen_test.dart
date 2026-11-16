import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk_flutter/l10n/app_localizations.dart' as ndk_l10n;
import 'package:ndk_flutter/ndk_flutter.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/features/common/material_host.dart';
import 'package:openmaps/features/social/screens/profile_screen.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/social.dart';

/// The profile screen hosts ndk_flutter's `NLogin`, which is built from the
/// deprecated `package:flutter/material.dart` library. Its `TextField` asserts
/// a `Material` ancestor of that same library, which neither the Play UI nor
/// `material_ui` provides — only [MaterialHost] does. Without it this build
/// throws "No Material widget found."
void main() {
  testWidgets('signed-out profile hosts NLogin without a Material crash', (
    WidgetTester tester,
  ) async {
    final Ndk ndk = Ndk(
      NdkConfig(
        cache: MemCacheManager(),
        eventVerifier: Bip340EventVerifier(),
        bootstrapRelays: const <String>[],
        // Otherwise Ndk starts a 15s periodic retry timer that the widget-test
        // binding flags as pending after the tree is torn down.
        pendingDeliveryRetriesEnabled: false,
      ),
    );
    final NdkFlutter ndkFlutter = NdkFlutter(ndk: ndk);
    final FakeSocialService social = FakeSocialService(signedIn: false);
    addTearDown(social.dispose);

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        ndkFlutterProvider.overrideWithValue(ndkFlutter),
        socialServiceProvider.overrideWithValue(social),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates:
              ndk_l10n.AppLocalizations.localizationsDelegates,
          supportedLocales: ndk_l10n.AppLocalizations.supportedLocales,
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialHost), findsOneWidget);
    expect(find.byType(NLogin), findsOneWidget);
    expect(find.text('Sign in to Nostr'), findsOneWidget);
  });
}
