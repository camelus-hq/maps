import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/fakes/fake_feedback_service.dart';
import 'package:openmaps/domain/usecases/send_feedback.dart';

void main() {
  Uint8List png([int length = 32]) =>
      Uint8List.fromList(List<int>.generate(length, (int i) => i % 256));

  test('trims the message and forwards the screenshot and context', () async {
    final FakeFeedbackService service = FakeFeedbackService();
    final SendFeedback usecase = SendFeedback(service);

    await usecase(
      message: '  The map froze when I zoomed  ',
      screenshot: png(),
      context: 'OpenMaps 0.4.0 (21) · android',
    );

    expect(service.sent.single.key, 'The map froze when I zoomed');
    expect(service.lastScreenshot, isNotNull);
    expect(service.lastScreenshot!.length, 32);
    expect(service.lastContext, 'OpenMaps 0.4.0 (21) · android');
  });

  test('an empty context is dropped', () async {
    final FakeFeedbackService service = FakeFeedbackService();
    await SendFeedback(service)(
      message: 'hi',
      screenshot: png(),
      context: '   ',
    );
    expect(service.lastContext, isNull);
  });

  test('rejects an empty message', () async {
    final FakeFeedbackService service = FakeFeedbackService();
    await expectLater(
      SendFeedback(service)(message: '   ', screenshot: png()),
      throwsA(isA<ValidationException>()),
    );
    expect(service.sent, isEmpty);
  });

  test('rejects an oversized message', () async {
    final FakeFeedbackService service = FakeFeedbackService();
    await expectLater(
      SendFeedback(service)(
        message: 'a' * (SendFeedback.maxMessageLength + 1),
        screenshot: png(),
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(service.sent, isEmpty);
  });

  test('rejects a screenshot that is not an image', () async {
    final FakeFeedbackService service = FakeFeedbackService();
    await expectLater(
      SendFeedback(service)(message: 'hi', screenshot: Uint8List(2)),
      throwsA(isA<ValidationException>()),
    );
    expect(service.sent, isEmpty);
  });

  test('sends while signed out (from the anonymous identity)', () async {
    final FakeFeedbackService service = FakeFeedbackService(signedIn: false);
    await SendFeedback(service)(message: 'hi', screenshot: png());
    expect(service.sent.single.key, 'hi');
  });
}
