import '../../../domain/entities/live_share.dart';
import '../../../domain/ports/app_database.dart';
import '../../../domain/ports/live_share_preferences.dart';
import 'app_database_values.dart';

/// [LiveSharePreferences] backed by the local [AppDatabase].
///
/// The last-used recipients and duration are stored as JSON values under the
/// `liveShare.*` keys, so remembering them needs no schema change and both
/// backends store byte-for-byte the same thing.
class DatabaseLiveSharePreferences implements LiveSharePreferences {
  DatabaseLiveSharePreferences({required this.database});

  final AppDatabase database;

  /// Public keys of the last share's recipients.
  static const String recipientsKey = 'liveShare.lastRecipients';

  /// Minutes of the last share's duration.
  static const String durationMinutesKey = 'liveShare.lastDurationMinutes';

  static final RegExp _hexPubkey = RegExp(r'^[0-9a-f]{64}$');

  @override
  Future<LiveShareDefaults> load() async {
    final List<String>? stored = await database.readStringList(recipientsKey);
    final List<String> recipients = <String>[
      for (final String pubkey in stored ?? const <String>[])
        if (_hexPubkey.hasMatch(pubkey)) pubkey,
    ];
    return LiveShareDefaults(
      recipients: List<String>.unmodifiable(recipients),
      duration: liveShareDurationForMinutes(
        await database.readInt(durationMinutesKey),
      ),
    );
  }

  @override
  Future<void> save(LiveShareDefaults defaults) async {
    await database.writeStringList(recipientsKey, defaults.recipients);
    final Duration? duration = defaults.duration;
    if (duration == null) {
      await database.deleteSetting(durationMinutesKey);
    } else {
      await database.writeInt(durationMinutesKey, duration.inMinutes);
    }
  }
}
