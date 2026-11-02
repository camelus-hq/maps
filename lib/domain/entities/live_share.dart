import 'lat_lon.dart';

/// One "for how long?" choice when starting a live-location share.
class LiveShareDuration {
  const LiveShareDuration(this.label, this.duration);

  /// User-facing label (e.g. "1 hour").
  final String label;

  /// How long the share runs from the moment it starts.
  final Duration duration;
}

/// The durations offered in the share sheet, mirroring the reference app's row.
const List<LiveShareDuration> liveShareDurations = <LiveShareDuration>[
  LiveShareDuration('30 min', Duration(minutes: 30)),
  LiveShareDuration('1 hour', Duration(hours: 1)),
  LiveShareDuration('4 hours', Duration(hours: 4)),
];

/// Default duration selected when the share sheet opens.
const Duration defaultLiveShareDuration = Duration(hours: 1);

/// The lifecycle of an outgoing live-location share.
enum LiveShareStatus {
  /// Nothing is being shared.
  idle,

  /// A share is being started (acquiring a fix, publishing the first update).
  starting,

  /// Actively sharing location updates with the selected friends.
  active,

  /// The last start attempt failed; [LiveShareState.error] explains why.
  error,
}

/// A persisted live-share session (survives an app restart).
class LiveShareSession {
  const LiveShareSession({
    required this.sessionId,
    required this.recipients,
    required this.startedAt,
    required this.expiresAt,
  });

  final String sessionId;

  /// Public keys of the friends who can see the location.
  final List<String> recipients;

  final DateTime startedAt;

  /// When the share stops on its own.
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      other is LiveShareSession &&
      other.sessionId == sessionId &&
      other.startedAt == startedAt &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(sessionId, startedAt, expiresAt);

  @override
  String toString() =>
      'LiveShareSession($sessionId, ${recipients.length} recipients)';
}

/// The outgoing live-share state surfaced to the UI.
class LiveShareState {
  const LiveShareState({
    this.status = LiveShareStatus.idle,
    this.recipients = const <String>[],
    this.startedAt,
    this.expiresAt,
    this.lastPublishedAt,
    this.error,
  });

  final LiveShareStatus status;

  /// Public keys currently allowed to see the location.
  final List<String> recipients;

  final DateTime? startedAt;

  /// When the share stops on its own.
  final DateTime? expiresAt;

  /// When the most recent update was published to the relays.
  final DateTime? lastPublishedAt;

  /// A user-safe message for the last failure, when [status] is error.
  final String? error;

  bool get isActive => status == LiveShareStatus.active;

  bool get isBusy => status == LiveShareStatus.starting;

  /// How many friends can see the location.
  int get recipientCount => recipients.length;

  /// Time left before the share stops on its own, or `null` when inactive.
  Duration? remainingAt(DateTime now) {
    final DateTime? end = expiresAt;
    if (end == null) {
      return null;
    }
    final Duration left = end.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  LiveShareState copyWith({
    LiveShareStatus? status,
    List<String>? recipients,
    DateTime? startedAt,
    DateTime? expiresAt,
    DateTime? lastPublishedAt,
    String? error,
    bool clearError = false,
  }) => LiveShareState(
    status: status ?? this.status,
    recipients: recipients ?? this.recipients,
    startedAt: startedAt ?? this.startedAt,
    expiresAt: expiresAt ?? this.expiresAt,
    lastPublishedAt: lastPublishedAt ?? this.lastPublishedAt,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  String toString() =>
      'LiveShareState(${status.name}, $recipientCount friends)';
}

/// What kind of live-location event is being broadcast.
enum LiveShareBroadcastKind {
  /// A position update (or the session's first payload).
  update,

  /// The share ended early, so recipients can drop the pin immediately.
  stop,
}

/// The payload gift-wrap encrypted to each recipient of a live share.
class LiveShareBroadcast {
  const LiveShareBroadcast({
    required this.sessionId,
    required this.kind,
    required this.position,
    required this.sampledAt,
    required this.expiresAt,
    this.accuracyMeters,
    this.heading,
    this.displayName,
  });

  final String sessionId;
  final LiveShareBroadcastKind kind;

  /// The last sampled position; `null` only if it was never known.
  final LatLon? position;

  /// When [position] was sampled (not when it was sent).
  final DateTime sampledAt;

  /// When the share ends on its own (recipients drop the pin at this point).
  final DateTime expiresAt;

  final double? accuracyMeters;
  final double? heading;

  /// The sender's display name, so a recipient can label the pin without an
  /// extra profile lookup.
  final String? displayName;
}
