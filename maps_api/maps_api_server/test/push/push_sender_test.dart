import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maps_api_server/src/push/fcm_sender.dart';
import 'package:maps_api_server/src/push/push_sender.dart';
import 'package:test/test.dart';

void main() {
  group('UnifiedPushSender', () {
    test('posts the wrapped event to the endpoint', () async {
      late http.Request captured;
      final MockClient client = MockClient((http.Request request) async {
        captured = request;
        return http.Response('ok', 200);
      });
      final UnifiedPushSender sender = UnifiedPushSender(client: client);

      final PushSendResult result = await sender.send(
        'https://ntfy.example.com/up/topic',
        '{"kind":1059}',
      );

      expect(result.ok, isTrue);
      expect(captured.url.toString(), 'https://ntfy.example.com/up/topic');
      expect(captured.body, '{"kind":1059}');
      expect(captured.headers['content-type'], contains('text/plain'));
    });

    test('404 marks the endpoint gone', () async {
      final MockClient client = MockClient(
        (http.Request request) async => http.Response('', 404),
      );
      final UnifiedPushSender sender = UnifiedPushSender(client: client);

      final PushSendResult result = await sender.send(
        'https://ntfy.example.com/up/topic',
        '{}',
      );

      expect(result.ok, isFalse);
      expect(result.invalidToken, isTrue);
    });

    test('a 500 is a retryable failure', () async {
      final MockClient client = MockClient(
        (http.Request request) async => http.Response('boom', 500),
      );
      final UnifiedPushSender sender = UnifiedPushSender(client: client);

      final PushSendResult result = await sender.send(
        'https://ntfy.example.com/up/topic',
        '{}',
      );

      expect(result.ok, isFalse);
      expect(result.invalidToken, isFalse);
    });
  });

  group('FcmSender.failureFromBody', () {
    test('UNREGISTERED is a dead token', () {
      final PushSendResult result = FcmSender.failureFromBody(
        '{"error":{"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}',
        404,
      );

      expect(result.ok, isFalse);
      expect(result.invalidToken, isTrue);
    });

    test('a plain 500 is retryable', () {
      final PushSendResult result = FcmSender.failureFromBody('{}', 500);

      expect(result.ok, isFalse);
      expect(result.invalidToken, isFalse);
    });
  });
}
