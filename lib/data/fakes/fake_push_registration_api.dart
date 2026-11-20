import 'dart:async';

import '../notifications/push_registrar.dart';

/// Records registrations for tests; accepts everything by default.
class FakePushRegistrationApi implements PushRegistrationApi {
  FakePushRegistrationApi({this.result = true, this.registerError});

  /// What [register]/[unregister] return — set `false` to simulate a server
  /// that rejects the registration.
  bool result;

  /// When set, [register] throws it (simulates an unreachable/failing server).
  Object? registerError;

  final List<String> registrations = <String>[];
  final List<({String proof, String? token})> unregistrations =
      <({String proof, String? token})>[];

  /// Proofs passed to [foreground] (one per opened session).
  final List<String> foregroundProofs = <String>[];

  /// How many foreground sessions are currently open (listened to).
  int openForegroundSessions = 0;

  @override
  Future<bool> register(String signedEventJson) async {
    final Object? error = registerError;
    if (error != null) {
      throw error;
    }
    registrations.add(signedEventJson);
    return result;
  }

  @override
  Future<bool> unregister(String signedEventJson, {String? token}) async {
    unregistrations.add((proof: signedEventJson, token: token));
    return result;
  }

  @override
  Stream<String> foreground(String signedEventJson) {
    foregroundProofs.add(signedEventJson);
    final StreamController<String> controller = StreamController<String>();
    controller.onListen = () {
      openForegroundSessions += 1;
      controller.add('active');
    };
    controller.onCancel = () => openForegroundSessions -= 1;
    return controller.stream;
  }
}
