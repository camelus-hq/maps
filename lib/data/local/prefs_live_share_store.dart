import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/live_share.dart';
import '../../domain/ports/live_share_store.dart';

/// [LiveShareStore] backed by `shared_preferences`.
///
/// Only the non-secret session metadata is stored (id, recipients, window) so
/// an active share can be restored and its notification rebuilt after a
/// restart. Nothing here is required to be secret.
class PrefsLiveShareStore implements LiveShareStore {
  static const String _key = 'openmaps.live_share.session';

  Future<SharedPreferences>? _prefs;

  Future<SharedPreferences> _instance() =>
      _prefs ??= SharedPreferences.getInstance();

  @override
  Future<LiveShareSession?> load() async {
    final SharedPreferences prefs = await _instance();
    final String? raw = prefs.getString(_key);
    return decodeSession(raw);
  }

  @override
  Future<void> save(LiveShareSession session) async {
    final SharedPreferences prefs = await _instance();
    await prefs.setString(_key, encodeSession(session));
  }

  @override
  Future<void> clear() async {
    final SharedPreferences prefs = await _instance();
    await prefs.remove(_key);
  }

  /// Encodes a session as JSON (exposed for the hostile-payload tests).
  static String encodeSession(LiveShareSession session) =>
      jsonEncode(<String, Object?>{
        'id': session.sessionId,
        'recipients': session.recipients,
        'startedAt': session.startedAt.millisecondsSinceEpoch,
        'expiresAt': session.expiresAt.millisecondsSinceEpoch,
      });

  /// Leniently decodes a stored session; anything malformed is treated as
  /// "nothing is being shared".
  static LiveShareSession? decodeSession(Object? raw) {
    final Object? decoded;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        return null;
      }
    } else {
      decoded = raw;
    }
    if (decoded is! Map<String, Object?>) {
      return null;
    }
    final Object? id = decoded['id'];
    if (id is! String || id.isEmpty || id.length > 64) {
      return null;
    }
    final Object? rawRecipients = decoded['recipients'];
    final List<String> recipients = <String>[];
    if (rawRecipients is List<Object?>) {
      for (final Object? entry in rawRecipients) {
        if (entry is String && _hexPubkey.hasMatch(entry.toLowerCase())) {
          recipients.add(entry.toLowerCase());
        }
      }
    }
    final int? startedAt = _asEpochMillis(decoded['startedAt']);
    final int? expiresAt = _asEpochMillis(decoded['expiresAt']);
    if (startedAt == null || expiresAt == null || expiresAt <= startedAt) {
      return null;
    }
    return LiveShareSession(
      sessionId: id,
      recipients: List<String>.unmodifiable(recipients),
      startedAt: DateTime.fromMillisecondsSinceEpoch(startedAt),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt),
    );
  }

  static final RegExp _hexPubkey = RegExp(r'^[0-9a-f]{64}$');

  static int? _asEpochMillis(Object? value) {
    final int? parsed = switch (value) {
      final int v => v,
      final double v => v.isFinite ? v.truncate() : null,
      final String v => int.tryParse(v),
      _ => null,
    };
    if (parsed == null || parsed <= 0) {
      return null;
    }
    // Bound absurd timestamps so a corrupt store can't create a session that
    // never ends.
    final DateTime time = DateTime.fromMillisecondsSinceEpoch(parsed);
    if (time.year < 2000 || time.year > 2100) {
      return null;
    }
    return parsed;
  }
}
