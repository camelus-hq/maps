import 'package:http/http.dart' as http;

/// An [http.Client] that always fails like a device with no connectivity
/// (`http.ClientException`, as `package:http` throws for a failed host lookup).
class OfflineHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw http.ClientException('Failed host lookup', request.url);
  }
}
