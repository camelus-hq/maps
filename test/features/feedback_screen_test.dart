import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/core/config/app_config.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/fakes/fake_app_version_source.dart';
import 'package:openmaps/data/fakes/fake_feedback_service.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/app_update.dart';
import 'package:openmaps/features/feedback/screens/feedback_screen.dart';
import 'package:openmaps/state/config.dart';
import 'package:openmaps/state/ports.dart';

/// A decodable 1×1 PNG, so `Image.memory` can render in a test.
Uint8List tinyPng() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
  'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  Future<ProviderContainer> pumpFeedback(
    WidgetTester tester, {
    AppConfig config = const AppConfig(feedbackPubkey: 'npub1example'),
    bool signedIn = true,
    FakeFeedbackService? service,
  }) async {
    final FakeFeedbackService feedback = service ?? FakeFeedbackService();
    // A tall viewport so the whole form (screenshot + field + button) is laid
    // out and tappable without scrolling.
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appConfigProvider.overrideWithValue(config),
        feedbackServiceProvider.overrideWithValue(feedback),
        socialServiceProvider.overrideWithValue(
          FakeSocialService(signedIn: signedIn),
        ),
        appVersionSourceProvider.overrideWithValue(
          FakeAppVersionSource(
            version: const AppVersion(versionCode: 21, versionName: '0.4.0'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final GoRouter router = GoRouter(
      initialLocation: '/feedback',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('home'))),
        ),
        GoRoute(
          path: '/feedback',
          builder: (BuildContext context, GoRouterState state) =>
              FeedbackScreen(screenshot: tinyPng()),
        ),
        GoRoute(
          path: '/profile',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('profile'))),
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
    return container;
  }

  testWidgets('sends the message with the screenshot and thanks the user', (
    WidgetTester tester,
  ) async {
    final FakeFeedbackService service = FakeFeedbackService();
    await pumpFeedback(tester, service: service);

    expect(find.byType(Image), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'The map froze');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(service.sent.single.key, 'The map froze');
    expect(find.text('Thanks! Your feedback was sent.'), findsOneWidget);
    // The screen leaves itself after a successful send.
    expect(find.text('Send feedback'), findsNothing);
  });

  testWidgets('the send button stays disabled until there is a message', (
    WidgetTester tester,
  ) async {
    await pumpFeedback(tester);

    final FilledButton before = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(before.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pumpAndSettle();

    final FilledButton after = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(after.onPressed, isNotNull);
  });

  testWidgets('without a recipient key the build explains itself', (
    WidgetTester tester,
  ) async {
    await pumpFeedback(tester, config: const AppConfig());

    expect(find.textContaining("isn't set up"), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pumpAndSettle();
    final FilledButton button = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a signed-out visitor can still send, anonymously', (
    WidgetTester tester,
  ) async {
    final FakeFeedbackService service = FakeFeedbackService(signedIn: false);
    await pumpFeedback(tester, signedIn: false, service: service);

    expect(
      find.textContaining('sent from an anonymous identity'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pumpAndSettle();
    final FilledButton button = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(service.sent.single.key, 'hello');
  });

  testWidgets('a failed send shows the error and keeps the form', (
    WidgetTester tester,
  ) async {
    final FakeFeedbackService service = FakeFeedbackService();
    await pumpFeedback(tester, service: service);

    // A send failure (no relay reached).
    service.error = const NetworkException('no relay accepted it');
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text('no relay accepted it'), findsOneWidget);
    expect(find.text('Send feedback'), findsOneWidget);
  });
}
