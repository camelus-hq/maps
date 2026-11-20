import 'dart:async';
import 'dart:convert';

import 'package:ndk/ndk.dart' as ndk;
import 'package:web_socket_channel/web_socket_channel.dart';

/// A single Nostr relay WebSocket connection used by the push forwarder.
///
/// Deliberately small: it speaks just enough of NIP-01 (`REQ`/`CLOSE`, and
/// `EVENT`/`EOSE`/`NOTICE`/`OK` frames) to keep one live subscription open, and
/// reconnects with backoff. It is a server-side listener, so it never signs or
/// publishes. Every (re)connect emits [onOpen], which the owner uses to
/// (re)issue its `REQ`.
class PushRelay {
  PushRelay(this.url, {this.options = const PushRelayOptions()}) {
    unawaited(_connect());
  }

  final String url;
  final PushRelayOptions options;

  WebSocketChannel? _socket;
  bool _closed = false;
  bool _reconnecting = false;
  int _reconnectDelayMs = 2000;
  int _reconnectAttempts = 0;

  final StreamController<PushRelay> _open = StreamController.broadcast();
  final StreamController<ndk.Nip01Event> _event = StreamController.broadcast();
  final StreamController<Object> _error = StreamController.broadcast();

  /// Fires after every successful (re)connection.
  Stream<PushRelay> get onOpen => _open.stream;

  Stream<ndk.Nip01Event> get onEvent => _event.stream;
  Stream<Object> get onError => _error.stream;

  Future<void> _connect() async {
    if (_closed) {
      return;
    }
    try {
      final WebSocketChannel socket = WebSocketChannel.connect(Uri.parse(url));
      await socket.ready;
      _socket = socket;
      socket.stream.listen(
        _handleMessage,
        onDone: _handleClose,
        onError: _handleError,
        cancelOnError: false,
      );
      _reconnectDelayMs = 2000;
      _reconnectAttempts = 0;
      _open.add(this);
    } catch (error) {
      _error.add(error);
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic raw) {
    if (raw is! String) {
      return;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! List || decoded.length < 2) {
      return;
    }
    switch (decoded[0]) {
      case 'EVENT':
        if (decoded.length < 3) {
          return;
        }
        try {
          _event.add(
            ndk.Nip01EventModel.fromJson(decoded[2] as Map<String, dynamic>),
          );
        } catch (error) {
          _error.add(error);
        }
      case 'NOTICE':
        _error.add('relay notice: ${decoded.length > 1 ? decoded[1] : ''}');
      case 'CLOSED':
        // A relay refusing the subscription (most often `auth-required` on a
        // `#p` filter) means it will forward nothing; surface it so the
        // operator can move the forwarder to a relay it may read.
        _error.add(
          'subscription closed by relay: '
          '${decoded.length > 2 ? decoded[2] : 'no reason given'}',
        );
      case 'AUTH':
        _error.add(
          'relay demands NIP-42 auth; the forwarder holds no user keys and '
          'cannot read an auth-gated #p filter here',
        );
    }
  }

  void _handleError(Object error) {
    if (!_closed) {
      _error.add(error);
    }
  }

  void _handleClose() {
    _socket = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closed || _reconnecting || !options.reconnect) {
      return;
    }
    _reconnecting = true;
    Timer(Duration(milliseconds: _reconnectDelayMs), () async {
      _reconnecting = false;
      _reconnectDelayMs = (_reconnectDelayMs * 3 ~/ 2).clamp(2000, 60000);
      _reconnectAttempts += 1;
      if (_reconnectAttempts > 20) {
        _error.add('too many reconnection attempts for $url');
        close();
        return;
      }
      await _connect();
    });
  }

  /// Sends a `REQ` for [subId]. A no-op while disconnected.
  void subscribe(String subId, Object filter) {
    _socket?.sink.add(jsonEncode(<Object>['REQ', subId, filter]));
  }

  void unsubscribe(String subId) {
    _socket?.sink.add(jsonEncode(<Object>['CLOSE', subId]));
  }

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    unawaited(_socket?.sink.close());
    _socket = null;
    unawaited(_open.close());
    unawaited(_event.close());
    unawaited(_error.close());
  }
}

class PushRelayOptions {
  const PushRelayOptions({this.reconnect = true});

  final bool reconnect;
}

/// A set of [PushRelay] connections treated as one stream.
///
/// The forwarder subscribes once per relay; events from every relay are merged,
/// so a share published to any of the recipient's relays is seen (duplicates
/// across relays are removed by the caller's dedup cache).
class PushRelayPool {
  PushRelayPool(
    Iterable<String> urls, {
    this.options = const PushRelayOptions(),
  }) {
    for (final String url in urls) {
      add(url);
    }
  }

  final PushRelayOptions options;
  final List<PushRelay> _relays = <PushRelay>[];

  final StreamController<PushRelay> _open = StreamController.broadcast();
  final StreamController<ndk.Nip01Event> _event = StreamController.broadcast();
  final StreamController<PushRelayError> _error = StreamController.broadcast();

  Stream<PushRelay> get onOpen => _open.stream;
  Stream<ndk.Nip01Event> get onEvent => _event.stream;
  Stream<PushRelayError> get onError => _error.stream;

  List<PushRelay> get relays => List<PushRelay>.unmodifiable(_relays);

  bool has(String url) => _relays.any((PushRelay relay) => relay.url == url);

  /// Adds and connects [url]; returns `false` when already present.
  bool add(String url) {
    if (has(url)) {
      return false;
    }
    final PushRelay relay = PushRelay(url, options: options);
    _relays.add(relay);
    relay.onOpen.listen(_open.add);
    relay.onEvent.listen(_event.add);
    relay.onError.listen(
      (Object error) => _error.add(PushRelayError(relay, error)),
    );
    return true;
  }

  /// Removes and closes [url]; returns `false` when it was not connected.
  bool remove(String url) {
    final int index = _relays.indexWhere((PushRelay relay) => relay.url == url);
    if (index < 0) {
      return false;
    }
    _relays.removeAt(index).close();
    return true;
  }

  /// Subscribes every current connection.
  void subscribe(String subId, Object filter) {
    for (final PushRelay relay in _relays) {
      relay.subscribe(subId, filter);
    }
  }

  /// Closes a subscription on every current connection.
  void unsubscribe(String subId) {
    for (final PushRelay relay in _relays) {
      relay.unsubscribe(subId);
    }
  }

  void close() {
    for (final PushRelay relay in _relays) {
      relay.close();
    }
    _relays.clear();
    unawaited(_open.close());
    unawaited(_event.close());
    unawaited(_error.close());
  }
}

class PushRelayError {
  const PushRelayError(this.relay, this.error);

  final PushRelay relay;
  final Object error;
}
