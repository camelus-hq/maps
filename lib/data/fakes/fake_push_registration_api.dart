import '../notifications/push_registrar.dart';

/// Records registrations for tests; accepts everything.
class FakePushRegistrationApi implements PushRegistrationApi {
  final List<String> registrations = <String>[];
  final List<({String proof, String? token})> unregistrations =
      <({String proof, String? token})>[];

  @override
  Future<bool> register(String signedEventJson) async {
    registrations.add(signedEventJson);
    return true;
  }

  @override
  Future<bool> unregister(String signedEventJson, {String? token}) async {
    unregistrations.add((proof: signedEventJson, token: token));
    return true;
  }
}
