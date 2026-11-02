/// A browsable place category: the chips under the search bar *and* the rows of
/// the category picker sheet.
///
/// Pure Dart — the control-channel command layer uses it without knowing about
/// the iconography in the feature layer. Each category carries the OpenStreetMap
/// tagging it stands for ([osmKey]/[osmValues], from the public `Key:amenity`
/// vocabulary plus a few leisure/shop/tourism ones) and an optional Mapbox
/// Search Box category id, so both [SearchService] implementations can map an id
/// without the domain depending on either API's query syntax.
class PlaceCategory {
  const PlaceCategory(
    this.id,
    this.label,
    this.group, {
    this.osmKey = 'amenity',
    this.osmValues = const <String>[],
    this.mapboxId,
  });

  /// Stable identifier (the OpenStreetMap `amenity` value for amenity rows).
  final String id;

  /// Human-readable label shown on a chip.
  final String label;

  /// Grouping in the picker sheet (from the OSM wiki's amenity sections).
  final String group;

  /// The OpenStreetMap key this category matches (`amenity` by default).
  final String osmKey;

  /// The OpenStreetMap values this category matches; empty means `[id]`.
  final List<String> osmValues;

  /// Mapbox Search Box canonical category id, when Mapbox has an index for it.
  /// `null` means the Mapbox backend has no category for it, so browsing it is
  /// an error (`UnsupportedException`) rather than a silent fallback.
  final String? mapboxId;

  /// The OpenStreetMap values to match (falls back to the id).
  List<String> get osmValueList => osmValues.isEmpty ? <String>[id] : osmValues;

  @override
  bool operator ==(Object other) => other is PlaceCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// Group headings, mirroring the OpenStreetMap wiki's `Key:amenity` sections
// (https://wiki.openstreetmap.org/wiki/Key:amenity), plus a small "Shops &
// leisure" group for the handful of non-amenity categories we browse.
const String _sustenance = 'Sustenance';
const String _education = 'Education';
const String _transportation = 'Transportation';
const String _financial = 'Financial';
const String _healthcare = 'Healthcare';
const String _entertainment = 'Entertainment & culture';
const String _publicService = 'Public service';
const String _facilities = 'Facilities';
const String _waste = 'Waste management';
const String _other = 'Other amenities';
const String _shopsLeisure = 'Shops & leisure';

/// The ordered group headings shown in the category picker sheet.
const List<String> categoryGroups = <String>[
  _sustenance,
  _transportation,
  _facilities,
  _shopsLeisure,
  _education,
  _healthcare,
  _financial,
  _entertainment,
  _publicService,
  _waste,
  _other,
];

/// Every browsable category, in picker-sheet order.
const List<PlaceCategory> placeCategories = <PlaceCategory>[
  // Sustenance ------------------------------------------------------------
  PlaceCategory('bar', 'Bars', _sustenance, mapboxId: 'bar'),
  PlaceCategory('biergarten', 'Biergarten', _sustenance),
  PlaceCategory('cafe', 'Cafes', _sustenance, mapboxId: 'cafe'),
  PlaceCategory('fast_food', 'Fast food', _sustenance, mapboxId: 'fast_food'),
  PlaceCategory('food_court', 'Food court', _sustenance),
  PlaceCategory('ice_cream', 'Ice cream', _sustenance),
  PlaceCategory('pub', 'Pubs', _sustenance),
  PlaceCategory(
    'restaurant',
    'Restaurants',
    _sustenance,
    mapboxId: 'restaurant',
  ),

  // Transportation --------------------------------------------------------
  PlaceCategory('bicycle_parking', 'Bicycle parking', _transportation),
  PlaceCategory(
    'bicycle_repair_station',
    'Bicycle repair station',
    _transportation,
  ),
  PlaceCategory('bicycle_rental', 'Bicycle rental', _transportation),
  PlaceCategory('bicycle_wash', 'Bicycle wash', _transportation),
  PlaceCategory('boat_rental', 'Boat rental', _transportation),
  PlaceCategory('boat_sharing', 'Boat sharing', _transportation),
  PlaceCategory('boat_storage', 'Boat storage', _transportation),
  PlaceCategory('bus_station', 'Bus station', _transportation),
  PlaceCategory('car_rental', 'Car rental', _transportation),
  PlaceCategory('car_sharing', 'Car sharing', _transportation),
  PlaceCategory('car_wash', 'Car wash', _transportation),
  PlaceCategory('charging_station', 'Charging station', _transportation),
  PlaceCategory('compressed_air', 'Compressed air', _transportation),
  PlaceCategory('driver_training', 'Driver training', _transportation),
  PlaceCategory('ferry_terminal', 'Ferry terminal', _transportation),
  PlaceCategory(
    'fuel',
    'Gas stations',
    _transportation,
    mapboxId: 'gas_station',
  ),
  PlaceCategory('grit_bin', 'Grit bin', _transportation),
  PlaceCategory('motorcycle_parking', 'Motorcycle parking', _transportation),
  PlaceCategory('parking', 'Parking', _transportation, mapboxId: 'parking'),
  PlaceCategory('parking_entrance', 'Parking entrance', _transportation),
  PlaceCategory('parking_space', 'Parking space', _transportation),
  PlaceCategory('taxi', 'Taxi', _transportation),
  PlaceCategory('vehicle_inspection', 'Vehicle inspection', _transportation),
  PlaceCategory('weighbridge', 'Weighbridge', _transportation),

  // Facilities ------------------------------------------------------------
  PlaceCategory('bbq', 'BBQ', _facilities),
  PlaceCategory('bench', 'Benches', _facilities),
  PlaceCategory('check_in', 'Check-in', _facilities),
  PlaceCategory('dog_toilet', 'Dog toilet', _facilities),
  PlaceCategory('dressing_room', 'Dressing room', _facilities),
  PlaceCategory('drinking_water', 'Water fountain', _facilities),
  PlaceCategory('give_box', 'Give box', _facilities),
  PlaceCategory('lounge', 'Lounge', _facilities),
  PlaceCategory('mailroom', 'Mailroom', _facilities),
  PlaceCategory('parcel_locker', 'Parcel locker', _facilities),
  PlaceCategory('shelter', 'Shelter', _facilities),
  PlaceCategory('shower', 'Shower', _facilities),
  PlaceCategory('telephone', 'Telephone', _facilities),
  PlaceCategory('toilets', 'Toilets', _facilities),
  PlaceCategory('water_point', 'Water point', _facilities),
  PlaceCategory('watering_place', 'Watering place', _facilities),

  // Shops & leisure -------------------------------------------------------
  PlaceCategory(
    'grocery',
    'Groceries',
    _shopsLeisure,
    osmKey: 'shop',
    osmValues: <String>['supermarket', 'grocery', 'convenience', 'greengrocer'],
  ),
  PlaceCategory(
    'park',
    'Parks',
    _shopsLeisure,
    osmKey: 'leisure',
    osmValues: <String>['park', 'garden', 'nature_reserve'],
    mapboxId: 'park',
  ),
  PlaceCategory(
    'hotel',
    'Hotels',
    _shopsLeisure,
    osmKey: 'tourism',
    osmValues: <String>['hotel', 'hostel', 'guest_house', 'motel', 'apartment'],
    mapboxId: 'hotel',
  ),

  // Education -------------------------------------------------------------
  PlaceCategory('college', 'College', _education, mapboxId: 'college'),
  PlaceCategory('dancing_school', 'Dancing school', _education),
  PlaceCategory('driving_school', 'Driving school', _education),
  PlaceCategory('first_aid_school', 'First aid school', _education),
  PlaceCategory('kindergarten', 'Kindergarten', _education),
  PlaceCategory('language_school', 'Language school', _education),
  PlaceCategory('library', 'Library', _education, mapboxId: 'library'),
  PlaceCategory('music_school', 'Music school', _education),
  PlaceCategory('research_institute', 'Research institute', _education),
  PlaceCategory('school', 'School', _education, mapboxId: 'school'),
  PlaceCategory('surf_school', 'Surf school', _education),
  PlaceCategory('toy_library', 'Toy library', _education),
  PlaceCategory('traffic_park', 'Traffic park', _education),
  PlaceCategory('training', 'Training', _education),
  PlaceCategory('university', 'University', _education, mapboxId: 'university'),

  // Healthcare ------------------------------------------------------------
  PlaceCategory('clinic', 'Clinic', _healthcare),
  PlaceCategory('dentist', 'Dentist', _healthcare, mapboxId: 'dentist'),
  PlaceCategory('doctors', 'Doctors', _healthcare),
  PlaceCategory('hospital', 'Hospital', _healthcare, mapboxId: 'hospital'),
  PlaceCategory('nursing_home', 'Nursing home', _healthcare),
  PlaceCategory('pharmacy', 'Pharmacy', _healthcare, mapboxId: 'pharmacy'),
  PlaceCategory('social_facility', 'Social facility', _healthcare),
  PlaceCategory('veterinary', 'Veterinary', _healthcare),

  // Financial -------------------------------------------------------------
  PlaceCategory('atm', 'ATM', _financial, mapboxId: 'atm'),
  PlaceCategory('bank', 'Banks', _financial, mapboxId: 'bank'),
  PlaceCategory('bureau_de_change', 'Bureau de change', _financial),
  PlaceCategory('money_transfer', 'Money transfer', _financial),
  PlaceCategory('payment_centre', 'Payment centre', _financial),
  PlaceCategory('payment_terminal', 'Payment terminal', _financial),

  // Entertainment & culture ----------------------------------------------
  PlaceCategory('arts_centre', 'Arts centre', _entertainment),
  PlaceCategory('casino', 'Casino', _entertainment),
  PlaceCategory('cinema', 'Cinema', _entertainment, mapboxId: 'cinema'),
  PlaceCategory('community_centre', 'Community centre', _entertainment),
  PlaceCategory('conference_centre', 'Conference centre', _entertainment),
  PlaceCategory('events_venue', 'Events venue', _entertainment),
  PlaceCategory('exhibition_centre', 'Exhibition centre', _entertainment),
  PlaceCategory('fountain', 'Fountains', _entertainment),
  PlaceCategory('gambling', 'Gambling', _entertainment),
  PlaceCategory('music_venue', 'Music venue', _entertainment),
  PlaceCategory(
    'nightclub',
    'Nightclub',
    _entertainment,
    mapboxId: 'nightclub',
  ),
  PlaceCategory('planetarium', 'Planetarium', _entertainment),
  PlaceCategory('public_bookcase', 'Public bookcase', _entertainment),
  PlaceCategory('social_centre', 'Social centre', _entertainment),
  PlaceCategory('stage', 'Stage', _entertainment),
  PlaceCategory('studio', 'Studio', _entertainment),
  PlaceCategory('theatre', 'Theatre', _entertainment, mapboxId: 'theater'),

  // Public service --------------------------------------------------------
  PlaceCategory('courthouse', 'Courthouse', _publicService),
  PlaceCategory('fire_station', 'Fire station', _publicService),
  PlaceCategory('police', 'Police', _publicService, mapboxId: 'police'),
  PlaceCategory('post_box', 'Post box', _publicService),
  PlaceCategory('post_depot', 'Post depot', _publicService),
  PlaceCategory(
    'post_office',
    'Post office',
    _publicService,
    mapboxId: 'post_office',
  ),
  PlaceCategory('prison', 'Prison', _publicService),
  PlaceCategory('ranger_station', 'Ranger station', _publicService),
  PlaceCategory('townhall', 'Town hall', _publicService),

  // Waste management ------------------------------------------------------
  PlaceCategory('recycling', 'Recycling', _waste),
  PlaceCategory('sanitary_dump_station', 'Sanitary dump station', _waste),
  PlaceCategory('waste_basket', 'Waste basket', _waste),
  PlaceCategory('waste_disposal', 'Waste disposal', _waste),
  PlaceCategory('waste_transfer_station', 'Waste transfer station', _waste),

  // Other amenities -------------------------------------------------------
  PlaceCategory('animal_boarding', 'Animal boarding', _other),
  PlaceCategory('animal_shelter', 'Animal shelter', _other),
  PlaceCategory('animal_training', 'Animal training', _other),
  PlaceCategory('baking_oven', 'Baking oven', _other),
  PlaceCategory('clock', 'Clock', _other),
  PlaceCategory('crematorium', 'Crematorium', _other),
  PlaceCategory('dive_centre', 'Dive centre', _other),
  PlaceCategory('funeral_hall', 'Funeral hall', _other),
  PlaceCategory('grave_yard', 'Grave yard', _other),
  PlaceCategory('hunting_stand', 'Hunting stand', _other),
  PlaceCategory('hydrant', 'Hydrant', _other),
  PlaceCategory('internet_cafe', 'Internet cafe', _other),
  PlaceCategory('kitchen', 'Kitchen', _other),
  PlaceCategory('kneipp_water_cure', 'Kneipp water cure', _other),
  PlaceCategory('lounger', 'Lounger', _other),
  PlaceCategory('marketplace', 'Marketplace', _other),
  PlaceCategory('monastery', 'Monastery', _other),
  PlaceCategory('mortuary', 'Mortuary', _other),
  PlaceCategory('photo_booth', 'Photo booth', _other),
  PlaceCategory(
    'place_of_worship',
    'Place of worship',
    _other,
    mapboxId: 'place_of_worship',
  ),
  PlaceCategory('public_bath', 'Public bath', _other),
  PlaceCategory('vending_machine', 'Vending machine', _other),
];

/// The categories shown as chips before the user pins their own — the short
/// browse row the reference app ships.
const List<String> defaultPinnedCategoryIds = <String>[
  'park',
  'cafe',
  'drinking_water',
  'grocery',
  'toilets',
];

/// The most categories that may be pinned to the chip row at once.
const int maxPinnedCategories = 10;

final Map<String, PlaceCategory> _byId = <String, PlaceCategory>{
  for (final PlaceCategory category in placeCategories)
    category.id.toLowerCase(): category,
};

final Map<String, PlaceCategory> _byLabel = <String, PlaceCategory>{
  for (final PlaceCategory category in placeCategories)
    category.label.toLowerCase(): category,
};

/// The category with [id] (the OpenStreetMap value), or `null`.
PlaceCategory? placeCategoryById(String? id) {
  if (id == null) {
    return null;
  }
  return _byId[id.trim().toLowerCase()];
}

/// The category with the given display [label] (case-insensitive), or `null`.
PlaceCategory? placeCategoryByLabel(String? label) {
  if (label == null) {
    return null;
  }
  return _byLabel[label.trim().toLowerCase()];
}

/// Resolves [ids] to categories, dropping unknown ids, de-duplicating and
/// preserving order (used to render the pinned chip row from settings).
List<PlaceCategory> categoriesByIds(Iterable<String> ids) {
  final List<PlaceCategory> resolved = <PlaceCategory>[];
  final Set<String> seen = <String>{};
  for (final String id in ids) {
    final PlaceCategory? category = placeCategoryById(id);
    if (category != null && seen.add(category.id)) {
      resolved.add(category);
    }
  }
  return List<PlaceCategory>.unmodifiable(resolved);
}

/// Curated synonyms for the common categories, matched against the whole query.
const Map<String, List<String>> _searchSynonyms = <String, List<String>>{
  'restaurant': <String>[
    'restaurant',
    'restaurants',
    'food',
    'burger',
    'pizza',
    'diner',
    'sushi',
    'italian',
  ],
  'cafe': <String>[
    'cafe',
    'cafes',
    'coffee',
    'coffee shop',
    'coffeehouse',
    'bakery',
    'bistro',
  ],
  'bar': <String>['bar', 'bars', 'pub', 'pubs', 'drinks'],
  'fast_food': <String>['fast food', 'takeaway', 'takeout'],
  'ice_cream': <String>['ice cream', 'gelato'],
  'fuel': <String>[
    'gas',
    'gas station',
    'gas stations',
    'gas_station',
    'petrol',
    'petrol station',
    'fuel',
  ],
  'grocery': <String>[
    'grocery',
    'groceries',
    'supermarket',
    'supermarkets',
    'convenience store',
    'market',
  ],
  'hotel': <String>['hotel', 'hotels', 'hostel', 'hostels', 'lodging'],
  'park': <String>['park', 'parks', 'garden', 'gardens'],
  'pharmacy': <String>['pharmacy', 'pharmacies', 'chemist', 'drugstore'],
  'atm': <String>['atm', 'atms', 'cash machine', 'cashpoint'],
  'bank': <String>['bank', 'banks'],
  'toilets': <String>[
    'toilet',
    'toilets',
    'restroom',
    'restrooms',
    'wc',
    'bathroom',
  ],
  'drinking_water': <String>[
    'water fountain',
    'water fountains',
    'drinking water',
    'drinking fountain',
  ],
  'hospital': <String>['hospital', 'hospitals'],
  'clinic': <String>['clinic', 'clinics'],
  'doctors': <String>['doctor', 'doctors', 'gp'],
  'dentist': <String>['dentist', 'dentists'],
  'library': <String>['library', 'libraries'],
  'parking': <String>['parking', 'car park'],
  'police': <String>['police', 'police station'],
  'post_office': <String>['post office', 'postoffice'],
  'place_of_worship': <String>[
    'church',
    'churches',
    'mosque',
    'temple',
    'synagogue',
    'place of worship',
  ],
  'cinema': <String>['cinema', 'cinemas', 'movie theater', 'movies'],
  'theatre': <String>['theatre', 'theater'],
};

/// Matches a whole search query ("cafes", "coffee", "water fountain") to a
/// browse category, or `null` when the query is not a category.
///
/// The match is on the *whole* query — id, label or a curated synonym — so a
/// search for a place by name ("Harbour Coffee") is never swallowed by a
/// category.
PlaceCategory? placeCategoryForSearch(String? query) {
  if (query == null) {
    return null;
  }
  final String value = query.trim().toLowerCase();
  if (value.isEmpty) {
    return null;
  }
  final PlaceCategory? direct =
      placeCategoryById(value) ?? placeCategoryByLabel(value);
  if (direct != null) {
    return direct;
  }
  for (final MapEntry<String, List<String>> entry in _searchSynonyms.entries) {
    if (entry.value.contains(value)) {
      return placeCategoryById(entry.key);
    }
  }
  return null;
}

/// Best-effort match of a provider's place-category string ("burger
/// restaurant", "Coffee shop", "Gas") to a browse category: the whole value
/// first, then a word inside it. Returns `null` when nothing fits, so callers
/// can fall back to a text search.
PlaceCategory? placeCategoryFromText(String? text) {
  if (text == null) {
    return null;
  }
  final String value = text.trim().toLowerCase();
  if (value.isEmpty) {
    return null;
  }
  final PlaceCategory? direct = placeCategoryForSearch(value);
  if (direct != null) {
    return direct;
  }
  for (final MapEntry<String, List<String>> entry in _searchSynonyms.entries) {
    for (final String needle in entry.value) {
      if (_containsWord(value, needle)) {
        return placeCategoryById(entry.key);
      }
    }
  }
  for (final PlaceCategory category in placeCategories) {
    if (_containsWord(value, category.id)) {
      return category;
    }
  }
  return null;
}

bool _containsWord(String haystack, String needle) {
  if (needle.isEmpty) {
    return false;
  }
  final int index = haystack.indexOf(needle);
  if (index < 0) {
    return false;
  }
  final bool startOk =
      index == 0 || !_isWordChar(haystack.codeUnitAt(index - 1));
  final int end = index + needle.length;
  final bool endOk =
      end == haystack.length || !_isWordChar(haystack.codeUnitAt(end));
  return startOk && endOk;
}

bool _isWordChar(int codeUnit) {
  final bool digit = codeUnit >= 0x30 && codeUnit <= 0x39;
  final bool upper = codeUnit >= 0x41 && codeUnit <= 0x5A;
  final bool lower = codeUnit >= 0x61 && codeUnit <= 0x7A;
  return digit || upper || lower;
}
