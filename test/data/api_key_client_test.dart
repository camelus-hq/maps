import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openmaps/data/http/api_key_client.dart';

void main() {
  test('adds the X-API-Key header to every request', () async {
    late http.Request captured;
    final http.Client inner = MockClient((http.Request request) async {
      captured = request;
      return http.Response('{}', 200);
    });
    final ApiKeyClient client = ApiKeyClient(inner, apiKey: 'ck.secret');

    await client.get(Uri.parse('https://photon.map.camelus.app/api?q=x'));
    await client.post(
      Uri.parse('https://overpass.map.camelus.app/api/interpreter'),
      body: <String, String>{'data': 'node;'},
    );

    expect(captured.headers[ApiKeyClient.headerName], 'ck.secret');
    // The key never lands in the URL/query, so it cannot leak via logs.
    expect(captured.url.queryParameters.containsKey('apikey'), isFalse);
  });

  test('close closes the wrapped client', () {
    bool closed = false;
    final http.Client inner = MockClient((http.Request request) async {
      return http.Response('{}', 200);
    });
    final ApiKeyClient client = ApiKeyClient(
      _ClosableClient(inner, onClose: () => closed = true),
      apiKey: 'ck.secret',
    );

    client.close();
    expect(closed, isTrue);
  });

  test('a JSON POST still carries the key', () async {
    late http.Request captured;
    final http.Client inner = MockClient((http.Request request) async {
      captured = request;
      return http.Response(jsonEncode(<String, Object?>{'ok': true}), 200);
    });
    final ApiKeyClient client = ApiKeyClient(inner, apiKey: 'ck.secret');

    await client.post(
      Uri.parse('https://valhalla.map.camelus.app/route'),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: '{"locations":[]}',
    );

    expect(captured.headers[ApiKeyClient.headerName], 'ck.secret');
    expect(captured.headers['Content-Type'], contains('application/json'));
  });
}

class _ClosableClient extends http.BaseClient {
  _ClosableClient(this._inner, {required this.onClose});

  final http.Client _inner;
  final void Function() onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() => onClose();
}
