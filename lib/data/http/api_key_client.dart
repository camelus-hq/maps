import 'package:http/http.dart' as http;

/// Wraps a [http.Client] and adds an API key to every request.
///
/// The Camelus map services (`*.map.camelus.app`) authenticate with a key that
/// may be sent either as the `X-API-Key` header or an `?apikey=` query
/// parameter; we use the header so the key never lands in a URL, a log line or
/// an error message. An empty [apiKey] is a no-op, so key-less (public) hosts
/// can share the same wiring.
class ApiKeyClient extends http.BaseClient {
  ApiKeyClient(this._inner, {required this.apiKey});

  /// The header the Camelus services accept.
  static const String headerName = 'X-API-Key';

  final http.Client _inner;
  final String apiKey;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final String key = apiKey.trim();
    if (key.isNotEmpty) {
      request.headers[headerName] = key;
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
