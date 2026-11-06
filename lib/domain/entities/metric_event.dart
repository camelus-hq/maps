/// A single metric/telemetry event recorded in the local app database.
///
/// The store is **local only** — nothing in this app uploads metrics. The
/// shape is deliberately small and closed: a name, a timestamp, an optional
/// finite numeric value and bounded string labels. Both backends (ObjectBox on
/// native, drift on the web) store exactly this, so recording code never has to
/// know which one is active.
class MetricEvent {
  const MetricEvent({
    required this.name,
    required this.recordedAt,
    this.value,
    this.labels = const <String, String>{},
    this.id,
  });

  /// Builds an event, stamping the time unless [recordedAt] is given and
  /// sanitising [name]/[labels] so a hostile or buggy caller cannot bloat the
  /// store.
  factory MetricEvent.create(
    String name, {
    DateTime? recordedAt,
    double? value,
    Map<String, String> labels = const <String, String>{},
  }) => MetricEvent(
    name: sanitiseName(name),
    recordedAt: recordedAt ?? DateTime.now(),
    value: value != null && value.isFinite ? value : null,
    labels: sanitiseLabels(labels),
  );

  /// Longest stored name (a schema-drift guard, not a product limit).
  static const int maxNameLength = 80;

  /// Longest stored label key or value.
  static const int maxLabelLength = 160;

  /// Most labels kept on one event.
  static const int maxLabels = 24;

  /// Storage id, assigned by the backend. `null` before the event is inserted.
  final int? id;

  final String name;
  final DateTime recordedAt;

  /// Optional numeric payload (a duration in milliseconds, a count, …).
  final double? value;

  /// Free-form string labels.
  final Map<String, String> labels;

  /// Trims and length-bounds a metric name.
  static String sanitiseName(String name) {
    final String trimmed = name.trim();
    if (trimmed.length <= maxNameLength) {
      return trimmed;
    }
    return trimmed.substring(0, maxNameLength);
  }

  /// Drops empty keys, length-bounds key and value, and caps the count.
  static Map<String, String> sanitiseLabels(Map<String, String> labels) {
    final Map<String, String> result = <String, String>{};
    for (final MapEntry<String, String> entry in labels.entries) {
      if (result.length >= maxLabels) {
        break;
      }
      final String key = entry.key.trim();
      if (key.isEmpty) {
        continue;
      }
      result[_bound(key)] = _bound(entry.value);
    }
    return Map<String, String>.unmodifiable(result);
  }

  static String _bound(String value) => value.length <= maxLabelLength
      ? value
      : value.substring(0, maxLabelLength);

  @override
  String toString() => 'MetricEvent($name @ $recordedAt)';
}
