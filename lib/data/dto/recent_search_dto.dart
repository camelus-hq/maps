import 'dart:convert';

import '../../domain/entities/place.dart';
import '../../domain/entities/recent_search.dart';
import 'place_dto.dart';

/// Lenient JSON codec for persisting the recent-search list (places and text
/// queries) in the local database.
///
/// Hostile input is dropped rather than thrown: a malformed entry, an unknown
/// `type`, or a place missing its id/position reads back as nothing.
abstract final class RecentSearchDto {
  /// The cap on a stored query's length (prefs/database values are untrusted).
  static const int maxQueryLength = 200;

  static Map<String, Object?> toJson(RecentSearch entry) => switch (entry) {
    RecentPlaceSearch(:final Place place) => <String, Object?>{
      'type': 'place',
      'place': PlaceDto.toJson(place),
    },
    RecentTextSearch(:final String text) => <String, Object?>{
      'type': 'query',
      'text': text,
    },
  };

  static RecentSearch? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    switch (raw['type']) {
      case 'place':
        final Place? place = PlaceDto.fromJson(raw['place']);
        return place == null ? null : RecentPlaceSearch(place);
      case 'query':
        final Object? text = raw['text'];
        if (text is! String) {
          return null;
        }
        final String trimmed = text.trim();
        if (trimmed.isEmpty) {
          return null;
        }
        return RecentTextSearch(
          trimmed.length > maxQueryLength
              ? trimmed.substring(0, maxQueryLength)
              : trimmed,
        );
      default:
        return null;
    }
  }

  static String encodeList(List<RecentSearch> entries) =>
      jsonEncode(entries.map(toJson).toList(growable: false));

  static List<RecentSearch> decodeList(String? json) {
    if (json == null || json.isEmpty) {
      return const <RecentSearch>[];
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return const <RecentSearch>[];
    }
    if (decoded is! List<Object?>) {
      return const <RecentSearch>[];
    }
    final List<RecentSearch> entries = <RecentSearch>[];
    for (final Object? item in decoded) {
      final RecentSearch? entry = fromJson(item);
      if (entry != null) {
        entries.add(entry);
      }
    }
    return entries;
  }
}
