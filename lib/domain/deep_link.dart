// Copyright (C) 2026 1-leo

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import '../core/utils/osm_ref.dart';
import 'entities/camera.dart';
import 'entities/lat_lon.dart';
import 'entities/travel_mode.dart';

/// The route shapes the app can be deep-linked into.
///
/// The URL is the single shareable representation of "where the app is":
///
/// | Screen | URL |
/// |---|---|
/// | map home | `/` |
/// | search | `/search?q=<text>` |
/// | place details | `/place/<type>/<id>` (OSM) or `/place/<id>` |
/// | directions | `/directions?mode=…&origin=…&destination=…&stop=…` |
///
/// A map view is carried on any of them as `at=<lat>,<lon>,<zoom>z`
/// (a leading `@` is accepted when parsing, so a Google-Maps-style
/// `@52.48,13.36,13z` pastes in cleanly). Route endpoints are either an OSM
/// reference (`way/159230368`), a `lat,lon` pair, or the literal `here` for the
/// device's current location.
///
/// Everything here is pure Dart and total: parsing hostile URL text never
/// throws, it returns `null` or drops the offending field.
enum DeepLinkKind { map, search, place, directions }

/// A directions endpoint as it is carried in a URL.
sealed class EndpointRef {
  const EndpointRef();

  /// The literal that means "the device's current location".
  static const String hereToken = 'here';

  /// Parses an endpoint token — `here`, an OSM ref (`way/123`) or a `lat,lon`
  /// pair — or `null` for anything else.
  static EndpointRef? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    final String value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    if (value == hereToken) {
      return const HereEndpoint();
    }
    if (OsmRef.isRef(value)) {
      return OsmEndpoint(value.toLowerCase());
    }
    final int comma = value.indexOf(',');
    if (comma <= 0 || comma >= value.length - 1) {
      return null;
    }
    final LatLon? point = LatLon.tryParse(
      value.substring(0, comma),
      value.substring(comma + 1),
    );
    return point == null ? null : PointEndpoint(point);
  }

  /// The URL token for this endpoint.
  String encode();
}

/// The device's current location (`here`).
class HereEndpoint extends EndpointRef {
  const HereEndpoint();

  @override
  String encode() => EndpointRef.hereToken;
}

/// An OpenStreetMap element (`way/159230368`).
class OsmEndpoint extends EndpointRef {
  const OsmEndpoint(this.ref);

  final String ref;

  @override
  String encode() => ref;
}

/// A bare coordinate (`52.4877824,13.3660672`).
class PointEndpoint extends EndpointRef {
  const PointEndpoint(this.point);

  final LatLon point;

  @override
  String encode() => '${point.latitude},${point.longitude}';
}

/// A parsed or constructed app deep link.
class DeepLink {
  const DeepLink._({
    required this.kind,
    this.query,
    this.placeRef,
    this.mode,
    this.origin,
    this.stops = const <EndpointRef>[],
    this.destination,
    this.view,
  });

  /// The map home, optionally constrained to [view].
  const DeepLink.map({Camera? view})
    : this._(kind: DeepLinkKind.map, view: view);

  /// The search screen with an optional [query].
  const DeepLink.search({String? query, Camera? view})
    : this._(kind: DeepLinkKind.search, query: query, view: view);

  /// A place details sheet, addressed by [placeRef] (an OSM ref such as
  /// `way/159230368`, or any other place id).
  const DeepLink.place(String placeRef, {Camera? view})
    : this._(kind: DeepLinkKind.place, placeRef: placeRef, view: view);

  /// A directions preview with a travel [mode], endpoints and [stops].
  const DeepLink.directions({
    TravelMode? mode,
    EndpointRef? origin,
    List<EndpointRef> stops = const <EndpointRef>[],
    EndpointRef? destination,
    Camera? view,
  }) : this._(
         kind: DeepLinkKind.directions,
         mode: mode,
         origin: origin,
         stops: stops,
         destination: destination,
         view: view,
       );

  final DeepLinkKind kind;

  /// The search text, only meaningful for [DeepLinkKind.search].
  final String? query;

  /// The place id, only meaningful for [DeepLinkKind.place].
  final String? placeRef;

  /// Travel mode, only meaningful for [DeepLinkKind.directions].
  final TravelMode? mode;
  final EndpointRef? origin;
  final List<EndpointRef> stops;
  final EndpointRef? destination;

  /// The map view (`at=`), on any kind.
  final Camera? view;

  /// The canonical URL for this link.
  Uri toUri() {
    final String path = switch (kind) {
      DeepLinkKind.map => '/',
      DeepLinkKind.search => '/search',
      DeepLinkKind.place => _placePath(placeRef),
      DeepLinkKind.directions => '/directions',
    };
    // Built by hand rather than with `queryParameters` so coordinates and OSM
    // refs keep their literal `,` and `/` (`at=52.48,13.36,13z`,
    // `stop=way/159230368`) instead of `%2C`/`%2F`.
    final List<String> parts = <String>[];
    final String? text = query;
    if (kind == DeepLinkKind.search && text != null && text.trim().isNotEmpty) {
      parts.add('q=${_queryValue(text)}');
    }
    if (kind == DeepLinkKind.directions) {
      final TravelMode? mode = this.mode;
      if (mode != null) {
        parts.add('mode=${mode.name}');
      }
      final EndpointRef? origin = this.origin;
      if (origin != null) {
        parts.add('origin=${_queryValue(origin.encode())}');
      }
      final EndpointRef? destination = this.destination;
      if (destination != null) {
        parts.add('destination=${_queryValue(destination.encode())}');
      }
      for (final EndpointRef stop in stops) {
        parts.add('stop=${_queryValue(stop.encode())}');
      }
    }
    final Camera? view = this.view;
    if (view != null) {
      parts.add('at=${_queryValue(_encodeView(view))}');
    }
    return Uri(path: path, query: parts.isEmpty ? null : parts.join('&'));
  }

  /// Percent-encodes a query value, keeping `,` and `/` literal (both are legal
  /// in a query and make coordinates and OSM refs readable).
  static String _queryValue(String value) =>
      Uri.encodeQueryComponent(value)
          .replaceAll('%2C', ',')
          .replaceAll('%2F', '/');

  /// Parses [uri] into a link, or `null` when it is not one of the app's
  /// shareable routes (so the router can own it).
  static DeepLink? parse(Uri uri) {
    final List<String> segments = uri.pathSegments;
    final Camera? view = _parseView(uri.queryParameters['at']);
    if (segments.isEmpty) {
      return DeepLink.map(view: view);
    }
    switch (segments) {
      case <String>['search']:
        final String? text = uri.queryParameters['q'];
        return DeepLink.search(
          query: (text == null || text.trim().isEmpty) ? null : text,
          view: view,
        );
      case <String>['place', final String type, final String id]
          when type == OsmRef.node ||
              type == OsmRef.way ||
              type == OsmRef.relation:
        final String? ref = OsmRef.fromTypeAndId(type, int.tryParse(id) ?? 0);
        return ref == null ? null : DeepLink.place(ref, view: view);
      case <String>['place', final String id]:
        return id.isEmpty ? null : DeepLink.place(id, view: view);
      case <String>['directions']:
        final List<EndpointRef> stops = <EndpointRef>[];
        for (final String raw
            in uri.queryParametersAll['stop'] ?? const <String>[]) {
          final EndpointRef? stop = EndpointRef.tryParse(raw);
          if (stop != null) {
            stops.add(stop);
          }
        }
        return DeepLink.directions(
          mode: _parseMode(uri.queryParameters['mode']),
          origin: EndpointRef.tryParse(uri.queryParameters['origin']),
          stops: stops,
          destination: EndpointRef.tryParse(uri.queryParameters['destination']),
          view: view,
        );
      default:
        return null;
    }
  }

  /// Whether [other] addresses the same place, with loose camera equality so a
  /// round-tripped view is not treated as a change.
  bool sameAs(DeepLink other) {
    if (kind != other.kind ||
        query != other.query ||
        placeRef != other.placeRef ||
        mode != other.mode ||
        !_sameEndpoint(origin, other.origin) ||
        !_sameEndpoint(destination, other.destination) ||
        stops.length != other.stops.length) {
      return false;
    }
    for (int i = 0; i < stops.length; i++) {
      if (!_sameEndpoint(stops[i], other.stops[i])) {
        return false;
      }
    }
    return _sameView(view, other.view);
  }

  static String _placePath(String? placeRef) {
    final String ref = (placeRef ?? '').trim();
    if (OsmRef.isRef(ref)) {
      return '/place/$ref';
    }
    return '/place/${Uri.encodeComponent(ref)}';
  }

  static String _encodeView(Camera camera) =>
      '${camera.target.latitude},${camera.target.longitude},${camera.zoom}z';

  static Camera? _parseView(String? raw) {
    if (raw == null) {
      return null;
    }
    String value = raw.trim();
    if (value.startsWith('@')) {
      value = value.substring(1);
    }
    if (value.endsWith('z') || value.endsWith('Z')) {
      value = value.substring(0, value.length - 1);
    }
    final List<String> parts = value.split(',');
    if (parts.length < 2) {
      return null;
    }
    final LatLon? target = LatLon.tryParse(parts[0], parts[1]);
    if (target == null) {
      return null;
    }
    final double parsedZoom = parts.length >= 3
        ? (double.tryParse(parts[2].trim()) ?? 12)
        : 12;
    final double zoom = parsedZoom.isFinite
        ? parsedZoom.clamp(0.0, 22.0).toDouble()
        : 12;
    return Camera(target: target, zoom: zoom);
  }

  static TravelMode? _parseMode(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'drive' || 'driving' || 'car' => TravelMode.drive,
      'walk' || 'walking' || 'pedestrian' => TravelMode.walk,
      'cycle' || 'cycling' || 'bicycle' || 'bike' => TravelMode.cycle,
      'transit' || 'public' || 'bus' || 'train' => TravelMode.transit,
      _ => null,
    };
  }

  static bool _sameEndpoint(EndpointRef? a, EndpointRef? b) {
    if (a == null || b == null) {
      return a == b;
    }
    return switch ((a, b)) {
      (HereEndpoint(), HereEndpoint()) => true,
      (OsmEndpoint(ref: final String x), OsmEndpoint(ref: final String y)) =>
        x == y,
      (
        PointEndpoint(point: final LatLon x),
        PointEndpoint(point: final LatLon y),
      ) =>
        (x.latitude - y.latitude).abs() < 1e-7 &&
            (x.longitude - y.longitude).abs() < 1e-7,
      _ => false,
    };
  }

  static bool _sameView(Camera? a, Camera? b) {
    if (a == null || b == null) {
      return a == b;
    }
    return (a.target.latitude - b.target.latitude).abs() < 1e-5 &&
        (a.target.longitude - b.target.longitude).abs() < 1e-5 &&
        (a.zoom - b.zoom).abs() < 0.05;
  }

  @override
  String toString() => 'DeepLink(${toUri()})';
}
