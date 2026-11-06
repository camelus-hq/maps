import 'dart:convert';

import '../../../domain/entities/metric_event.dart';

/// Encodes and decodes [MetricEvent] label maps for storage.
///
/// Kept in one place so the ObjectBox and drift adapters store identical bytes.
/// Decoding is hostile-safe: a malformed or non-object value yields an empty
/// map (never a throw), non-string entries are dropped, and the count is capped.
abstract final class MetricEventCodec {
  static String encodeLabels(Map<String, String> labels) => jsonEncode(labels);

  static Map<String, String> decodeLabels(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const <String, String>{};
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const <String, String>{};
    }
    if (decoded is! Map<String, Object?>) {
      return const <String, String>{};
    }
    final Map<String, String> result = <String, String>{};
    for (final MapEntry<String, Object?> entry in decoded.entries) {
      if (result.length >= MetricEvent.maxLabels) {
        break;
      }
      final Object? value = entry.value;
      if (value is String) {
        result[entry.key] = value;
      }
    }
    return Map<String, String>.unmodifiable(result);
  }
}
