import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'push_config.dart';

/// The outcome of one push send.
class PushSendResult {
  const PushSendResult.success()
    : ok = true,
      invalidToken = false,
      error = null;

  const PushSendResult.failure({this.invalidToken = false, this.error})
    : ok = false;

  /// Whether the push service accepted the message.
  final bool ok;

  /// Whether the destination should be deleted (FCM said the token is gone, or
  /// the UnifiedPush endpoint answered 404/410).
  final bool invalidToken;

  /// A short reason for a failure, for logging.
  final String? error;
}

/// Sends one already-encrypted gift-wrap payload to one destination token.
///
/// Implementations never see plaintext: the payload handed to [send] is the
/// serialized NIP-59 gift wrap, so neither the transport provider (FCM) nor the
/// UnifiedPush distributor can read the message.
abstract interface class PushSender {
  /// The `transport` value this sender handles (`firebase` / `unifiedpush`).
  String get transport;

  /// Sends [encryptedEventJson] to [token].
  Future<PushSendResult> send(String token, String encryptedEventJson);
}

/// Picks the [PushSender] for a subscription's declared transport.
class PushSenderRegistry {
  PushSenderRegistry(Iterable<PushSender> senders)
    : _senders = <String, PushSender>{
        for (final PushSender sender in senders) sender.transport: sender,
      };

  final Map<String, PushSender> _senders;

  PushSender? forTransport(String transport) => _senders[transport];

  Iterable<String> get transports => _senders.keys;
}

/// Sends through a **UnifiedPush** endpoint (ntfy and compatible distributors).
///
/// The endpoint is a plain HTTP URL; posting the wrapped event as the request
/// body delivers it to the device's distributor, which wakes the app. A 404/410
/// means the endpoint is gone and the token is deleted.
class UnifiedPushSender implements PushSender {
  UnifiedPushSender({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get transport => 'unifiedpush';

  @override
  Future<PushSendResult> send(String token, String encryptedEventJson) async {
    final Uri? endpoint = Uri.tryParse(token);
    if (endpoint == null || !endpoint.hasScheme) {
      return const PushSendResult.failure(
        invalidToken: true,
        error: 'invalid UnifiedPush endpoint',
      );
    }
    try {
      final http.Response response = await _client
          .post(
            endpoint,
            headers: const <String, String>{
              'content-type': 'text/plain; charset=utf-8',
            },
            body: encryptedEventJson,
          )
          .timeout(PushConfig.sendTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const PushSendResult.success();
      }
      if (response.statusCode == 404 || response.statusCode == 410) {
        return const PushSendResult.failure(
          invalidToken: true,
          error: 'endpoint no longer registered',
        );
      }
      return PushSendResult.failure(
        error: 'HTTP ${response.statusCode}',
      );
    } on TimeoutException {
      return const PushSendResult.failure(error: 'UnifiedPush send timed out');
    } catch (error) {
      return PushSendResult.failure(error: 'UnifiedPush send failed: $error');
    }
  }
}

/// Decodes a JSON error body without throwing (the FCM body is external data).
Map<String, dynamic>? tryDecodeObject(String body) {
  try {
    final Object? decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}
