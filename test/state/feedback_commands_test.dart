import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/config/app_config.dart';
import 'package:openmaps/data/fakes/fake_feedback_service.dart';
import 'package:openmaps/state/commands/command.dart';
import 'package:openmaps/state/commands/commands_provider.dart';
import 'package:openmaps/state/config.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/screenshot.dart';

void main() {
  // `feedback.open` reads the root navigator's GlobalKey, which needs the
  // widget binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'feedback.state reports the configuration and the send status',
    () async {
      final FakeFeedbackService fake = FakeFeedbackService();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          feedbackServiceProvider.overrideWithValue(fake),
          appConfigProvider.overrideWithValue(
            const AppConfig(feedbackPubkey: 'npub1example'),
          ),
        ],
      );
      addTearDown(container.dispose);

      final Map<String, Object?> state =
          await container
                  .read(commandRegistryProvider)
                  .dispatch('feedback.state', const <String, Object?>{})
              as Map<String, Object?>;

      expect(state['configured'], isTrue);
      expect(state['signedIn'], isTrue);
      expect(state['sender'], FakeFeedbackService.userPubkey);
      expect(state['status'], 'idle');
      expect(state['error'], isNull);
    },
  );

  test('feedback.send forwards the text and captures a screenshot', () async {
    final FakeFeedbackService fake = FakeFeedbackService();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        feedbackServiceProvider.overrideWithValue(fake),
        screenshotCaptureProvider.overrideWithValue(
          () async => Uint8List.fromList(List<int>.filled(24, 3)),
        ),
      ],
    );
    addTearDown(container.dispose);

    final Map<String, Object?> result =
        await container.read(commandRegistryProvider).dispatch(
          'feedback.send',
          <String, Object?>{'text': 'the map froze'},
        ) as Map<String, Object?>;

    expect(result['sent'], isTrue);
    expect(fake.sent.single.key, 'the map froze');
    expect(fake.lastScreenshot, hasLength(24));
  });

  test('feedback.send rejects an empty message before capturing', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(commandRegistryProvider).dispatch(
        'feedback.send',
        <String, Object?>{'text': '   '},
      ),
      throwsA(isA<CommandException>()),
    );
  });

  test('feedback.open needs a mounted app view', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        screenshotCaptureProvider.overrideWithValue(
          () async => Uint8List.fromList(List<int>.filled(8, 0)),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(commandRegistryProvider)
          .dispatch('feedback.open', const <String, Object?>{}),
      throwsA(isA<CommandException>()),
    );
  });
}
