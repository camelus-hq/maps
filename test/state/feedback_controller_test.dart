import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/fakes/fake_app_version_source.dart';
import 'package:openmaps/data/fakes/fake_feedback_service.dart';
import 'package:openmaps/domain/entities/app_update.dart';
import 'package:openmaps/state/feedback.dart';
import 'package:openmaps/state/ports.dart';

void main() {
  Uint8List png() => Uint8List.fromList(List<int>.filled(16, 1));

  test('send moves to sent and records the app context', () async {
    final FakeFeedbackService fake = FakeFeedbackService();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        feedbackServiceProvider.overrideWithValue(fake),
        appVersionSourceProvider.overrideWithValue(
          FakeAppVersionSource(
            version: const AppVersion(versionCode: 21, versionName: '0.4.0'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(feedbackControllerProvider.notifier)
        .send(message: 'hello', screenshot: png());

    expect(container.read(feedbackControllerProvider).isSent, isTrue);
    expect(fake.sent.single.key, 'hello');
    expect(fake.lastContext, contains('0.4.0 (21)'));
  });

  test('a failure surfaces the message and returns to idle', () async {
    final FakeFeedbackService fake = FakeFeedbackService()
      ..error = const NetworkException('no relay accepted it');
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[feedbackServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await container
        .read(feedbackControllerProvider.notifier)
        .send(message: 'hello', screenshot: png());

    final FeedbackState state = container.read(feedbackControllerProvider);
    expect(state.status, FeedbackStatus.idle);
    expect(state.error, 'no relay accepted it');
  });

  test('reset clears a previous result', () async {
    final FakeFeedbackService fake = FakeFeedbackService();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[feedbackServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await container
        .read(feedbackControllerProvider.notifier)
        .send(message: 'hello', screenshot: png());
    expect(container.read(feedbackControllerProvider).isSent, isTrue);

    container.read(feedbackControllerProvider.notifier).reset();
    expect(
      container.read(feedbackControllerProvider).status,
      FeedbackStatus.idle,
    );
  });
}
