import 'dart:async';

import '../../domain/entities/push.dart';
import '../../domain/ports/push_messaging.dart';

/// In-memory [PushMessaging] for tests and keyless runs.
class FakePushMessaging implements PushMessaging {
  FakePushMessaging({
    this.isSupported = true,
    Map<PushTransport, String>? tokens,
  }) : _tokens = <PushTransport, String>{...?tokens};

  @override
  final bool isSupported;

  final Map<PushTransport, String> _tokens;
  final StreamController<PushToken> _tokenChanges =
      StreamController<PushToken>.broadcast();
  final StreamController<String> _foreground =
      StreamController<String>.broadcast();

  bool initialized = false;
  int permissionRequests = 0;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests += 1;
    return isSupported;
  }

  @override
  Future<String?> tokenFor(PushTransport transport) async => _tokens[transport];

  @override
  Stream<PushToken> get tokenChanges => _tokenChanges.stream;

  @override
  Stream<String> get foregroundMessages => _foreground.stream;

  /// Provides (or refreshes) a token and notifies listeners.
  void setToken(PushTransport transport, String value) {
    _tokens[transport] = value;
    _tokenChanges.add(PushToken(transport: transport, value: value));
  }

  /// Delivers an encrypted gift-wrap payload as if it arrived in the foreground.
  void emitForeground(String encryptedEvent) => _foreground.add(encryptedEvent);

  /// Tokens invalidated through [deleteToken], for assertions.
  final List<PushTransport> deletedTokens = <PushTransport>[];

  @override
  Future<void> deleteToken(PushTransport transport) async {
    deletedTokens.add(transport);
    _tokens.remove(transport);
  }

  Future<void> dispose() async {
    await _tokenChanges.close();
    await _foreground.close();
  }
}
