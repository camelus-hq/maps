import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/place.dart';

/// Lenient mapper for Mapbox **Search Box** GeoJSON features
/// (`/search/searchbox/v1/...`), used for category ("near me") results.
///
/// Hostile-safe like the geocoding mapper: a malformed feature is dropped, never
/// thrown (AGENTS.md "Never crash").
abstract final class MapboxSearchBoxMapper {
  static Place? fromFeature(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return null;
    }
    final Object? properties = raw['properties'];
    if (properties is! Map<String, Object?>) {
      return null;
    }
    final Object? id = properties['mapbox_id'];
    final Object? name = properties['name'];
    if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
      return null;
    }
    final LatLon? position = _coordinates(raw, properties);
    if (position == null) {
      return null;
    }
    return Place(
      id: id,
      name: name,
      position: position,
      category: _category(properties),
      address: _address(properties),
    );
  }

  static LatLon? _coordinates(
    Map<String, Object?> raw,
    Map<String, Object?> properties,
  ) {
    // Newer shape: properties.coordinates.{latitude,longitude}.
    final Object? coords = properties['coordinates'];
    if (coords is Map<String, Object?>) {
      final LatLon? parsed = LatLon.tryParse(
        coords['latitude'],
        coords['longitude'],
      );
      if (parsed != null) {
        return parsed;
      }
    }
    // GeoJSON shape: geometry.coordinates = [lon, lat].
    final Object? geometry = raw['geometry'];
    if (geometry is Map<String, Object?>) {
      final Object? list = geometry['coordinates'];
      if (list is List<Object?> && list.length >= 2) {
        return LatLon.tryParse(list[1], list[0]);
      }
    }
    return null;
  }

  static String? _category(Map<String, Object?> properties) {
    final Object? categories = properties['poi_category'];
    if (categories is List<Object?> && categories.isNotEmpty) {
      final Object? first = categories.first;
      if (first is String && first.isNotEmpty) {
        return first;
      }
    }
    return null;
  }

  static String? _address(Map<String, Object?> properties) {
    final Object? full = properties['full_address'];
    if (full is String && full.isNotEmpty) {
      return full;
    }
    final Object? formatted = properties['place_formatted'];
    return formatted is String && formatted.isNotEmpty ? formatted : null;
  }
}
