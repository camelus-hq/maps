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
  LiveShareDuration('12 hours', Duration(hours: 12)),
  LiveShareDuration('24 hours', Duration(hours: 24)),
];

/// Default duration selected when the share sheet opens.
const Duration defaultLiveShareDuration = Duration(hours: 1);

/// The offered duration whose length is [minutes], or `null` when it is not one
/// of [liveShareDurations] (a removed or renamed option reads back as "not
/// set", so a later build never selects a choice the row no longer shows).
Duration? liveShareDurationForMinutes(int? minutes) {
  if (minutes == null) {
    return null;
  }
  for (final LiveShareDuration option in liveShareDurations) {
    if (option.duration.inMinutes == minutes) {
      return option.duration;
    }
  }
  return null;
}

/// The choices remembered from the last live-location share, so the share sheet
/// can pre-select who it went to and for how long the next time it opens.
class LiveShareDefaults {
  const LiveShareDefaults({this.recipients = const <String>[], this.duration});

  /// Public keys of the friends the last share went to. May name people who are
  /// no longer friends; callers intersect this with the current friend list.
  final List<String> recipients;

  /// The duration chosen last time, or `null` when it was never stored or is no
  /// longer an offered option (see [liveShareDurationForMinutes]).
  final Duration? duration;

  /// Whether nothing was remembered (a first share, or every stored value was
  /// dropped as invalid).
  bool get isEmpty => recipients.isEmpty && duration == null;

  @override
  bool operator ==(Object other) =>
      other is LiveShareDefaults &&
      _sameRecipients(other.recipients) &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(Object.hashAll(recipients), duration);

  bool _sameRecipients(List<String> other) {
    if (other.length != recipients.length) {
      return false;
    }
    for (int i = 0; i < recipients.length; i++) {
      if (recipients[i] != other[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() =>
      'LiveShareDefaults(${recipients.length} recipients, $duration)';
}

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
///
/// The kind also selects the wire envelope: **start** and **stop** are stored
/// NIP-59 gift wraps (kind `1059`) the push server forwards; an **update** is an
/// ephemeral wrap (kind `21059`) that only a listening app receives.
enum LiveShareBroadcastKind {
  /// The **first** payload of a session: the recipient is told the friend
  /// started sharing. Only this raises a notification, so a stream of position
  /// updates does not spam the recipient.
  start,

  /// A position update after the session's start.
  update,

  /// The share ended early, so recipients can drop the pin immediately.
  stop,
}

/// The payload gift-wrap encrypted to each recipient of a live share.
///
/// It carries only the share itself — no sender name or avatar. A recipient
/// resolves those from the sender's Nostr profile (`kind: 0`), so the wire
/// payload stays minimal and the identity is always the profile.
class LiveShareBroadcast {
  const LiveShareBroadcast({
    required this.sessionId,
    required this.kind,
    required this.position,
    required this.sampledAt,
    required this.expiresAt,
    this.accuracyMeters,
    this.heading,
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
}
