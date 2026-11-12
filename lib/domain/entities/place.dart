import '../../core/utils/osm_image.dart';
import '../../core/utils/osm_payments.dart';
import 'lat_lon.dart';

/// A search result, a saved place or a map POI.
///
/// Data is our own (Mapbox/geocoding) plus OpenStreetMap tags — never Google
/// Places. The contact/accessibility fields are optional: they come from an OSM
/// element lookup ([email], [phone], [website], [wheelchairAccessible],
/// [openingHours]) and stay `null` when we have no OSM tags for the place.
///
/// [osmTags] carries the raw OpenStreetMap tags the element publishes (bounded
/// and trimmed by the data layer); the small, typed views above it ([imageUrls],
/// [paymentMethods], [wheelchairDescription], …) are derived here so the sheet
/// never has to know OSM's key spelling.
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.position,
    this.category,
    this.address,
    this.email,
    this.phone,
    this.website,
    this.wheelchairAccessible,
    this.openingHours,
    this.osmTags = const <String, String>{},
  });

  final String id;
  final String name;
  final LatLon position;
  final String? category;
  final String? address;

  /// Contact e-mail (`contact:email` / `email`), when OSM publishes one.
  final String? email;

  /// Contact phone number (`contact:phone` / `phone` / `contact:mobile` /
  /// `mobile`), when OSM publishes one.
  final String? phone;

  /// Website (`website` / `contact:website` / `url`), when OSM publishes one.
  final String? website;

  /// `wheelchair=yes` / `designated` → true, `no` → false, unknown → null
  /// (OSM's own three-valued accessibility tag).
  final bool? wheelchairAccessible;

  /// The raw OSM `opening_hours` value, when present. Shown verbatim — we make
  /// no attempt to interpret it.
  final String? openingHours;

  /// The raw OpenStreetMap tags for the element (Overpass `tags`), bounded
  /// by the data layer. Never empty for a place when OSM publishes any tags.
  final Map<String, String> osmTags;

  /// Whether a phone number is known (drives the Call action).
  bool get hasPhone => phone != null && phone!.isNotEmpty;

  /// The direct image URLs from the `image` / `image:<n>` tags (empty when the
  /// place has none, or only non-`http(s)` values).
  List<String> get imageUrls => OsmImage.urls(osmTags);

  /// `wheelchair:description` — free text about a venue's accessibility.
  String? get wheelchairDescription => _tag('wheelchair:description', 300);

  /// The `takeaway` tag (`yes` / `no` / `only`), or `null` when untagged.
  String? get takeaway => _tag('takeaway', 20);

  /// `description:payment` — free text about how a place takes payment.
  String? get paymentDescription => _tag('description:payment', 300);

  /// The accepted `payment:*` methods, in a stable order.
  List<OsmPaymentMethod> get paymentMethods =>
      OsmPaymentCatalog.accepted(osmTags);

  /// The accepted crypto payment methods the sheet promotes below the review
  /// (`payment:lightning`, `payment:lightning_contactless`, `payment:cashu`,
  /// `payment:ecash`).
  List<OsmPaymentMethod> get promotedPayments =>
      OsmPaymentCatalog.promotedCrypto(osmTags);

  /// A present, trimmed OSM tag value bounded to [maxLength], or `null`.
  String? _tag(String key, int maxLength) {
    final String? raw = osmTags[key];
    if (raw == null) {
      return null;
    }
    final String value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    return value.length > maxLength ? value.substring(0, maxLength) : value;
  }

  /// This place with any missing fields filled in from an OSM lookup.
  ///
  /// The place we already hold wins where it has a value (Mapbox's display name
  /// and category are what the user tapped); OSM fills the gaps — most often the
  /// address, plus the contact/accessibility tags we never get from Mapbox.
  Place withOsmDetails(Place? osm) {
    if (osm == null || osm.id != id) {
      return this;
    }
    final String name = this.name.trim().isEmpty ? osm.name : this.name;
    return Place(
      id: id,
      name: name,
      position: position,
      category: category ?? osm.category,
      address: address ?? osm.address,
      email: email ?? osm.email,
      phone: phone ?? osm.phone,
      website: website ?? osm.website,
      wheelchairAccessible: wheelchairAccessible ?? osm.wheelchairAccessible,
      openingHours: openingHours ?? osm.openingHours,
      osmTags: osm.osmTags.isNotEmpty ? osm.osmTags : osmTags,
    );
  }

  @override
  bool operator ==(Object other) => other is Place && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Place($id, $name)';
}
