import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openmaps/core/config/app_config.dart';
import 'package:openmaps/data/fakes/fake_app_version_source.dart';
import 'package:openmaps/data/fakes/fake_feedback_service.dart';
import 'package:openmaps/domain/entities/app_update.dart';
import 'package:openmaps/features/feedback/screens/feedback_screen.dart';
import 'package:openmaps/features/feedback/widgets/alpha_banner.dart';
import 'package:openmaps/state/config.dart';
import 'package:openmaps/state/navigation_keys.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/screenshot.dart';

/// A decodable 1×1 PNG, so `Image.memory` can render in a test.
Uint8List tinyPng() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
  'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  test('alphaBannerLabel renders the current version', () {
    expect(
      alphaBannerLabel(const AppVersion(versionCode: 21, versionName: '0.4.0')),
      'alpha 0.4.0',
    );
    expect(alphaBannerLabel(AppVersion.unknown), 'alpha');
  });

  testWidgets('tapping the alpha banner opens the feedback form', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appVersionSourceProvider.overrideWithValue(
          FakeAppVersionSource(
            version: const AppVersion(versionCode: 21, versionName: '0.4.0'),
          ),
        ),
        screenshotCaptureProvider.overrideWithValue(() async => tinyPng()),
        feedbackServiceProvider.overrideWithValue(FakeFeedbackService()),
        appConfigProvider.overrideWithValue(
          const AppConfig(feedbackPubkey: 'npub1example'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: AlphaBannerHost(child: SizedBox.expand())),
        ),
        GoRoute(
          path: '/feedback',
          builder: (BuildContext context, GoRouterState state) {
            final Object? extra = state.extra;
            return FeedbackScreen(
              screenshot: extra is Uint8List ? extra : null,
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlphaBanner), findsOneWidget);
    final Offset topRight = tester.getTopRight(find.byType(AlphaBanner));
    // The ribbon is the diagonal band near the corner, not the whole box.
    await tester.tapAt(topRight + const Offset(-30, 30));
    await tester.pumpAndSettle();

    expect(find.text('Send feedback'), findsOneWidget);
  });
}
