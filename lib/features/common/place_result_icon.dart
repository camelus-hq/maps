import 'package:flutter/widgets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// The pin shown for an ordinary result — an address, a street, a town, a
/// locality, a building — anything whose category has no bespoke glyph.
const IconData _pin = PhosphorIconsRegular.mapPin;

/// A Phosphor icon for a place's provider category, or [_pin] for an ordinary
/// result (addresses, roads, localities, unknown types …).
///
/// The category comes from whichever backend answered the search — an
/// OpenStreetMap value (`bus_stop`, `subway_entrance`, `cafe`, `drinking_water`)
/// or a Mapbox category id (`train_station`, `coffee_shop`, `gas_station`) — so
/// the match is on the normalised, tokenised value rather than one provider's
/// exact spelling: `train_station` matches on `train`, `coffee_shop` on
/// `coffee`. Our own iconography (Phosphor Icons, MIT) — never an asset copied
/// from another app.
IconData placeResultIcon(String? category) {
  final String key = _normalise(category);
  if (key.isEmpty) {
    return _pin;
  }
  final IconData? exact = _exact[key];
  if (exact != null) {
    return exact;
  }
  for (final String token in key.split(' ')) {
    final IconData? icon = _icons[token];
    if (icon != null) {
      return icon;
    }
  }
  return _pin;
}

/// Categories that need a whole-value match (a bare token would be too broad):
/// a drinking-water tap is not just "water".
const Map<String, IconData> _exact = <String, IconData>{
  'drinking water': PhosphorIconsRegular.drop,
  'water point': PhosphorIconsRegular.drop,
  'water tap': PhosphorIconsRegular.drop,
  'water well': PhosphorIconsRegular.drop,
  'watering place': PhosphorIconsRegular.drop,
};

/// The first recognised token of a category wins, in the order it appears, so
/// `gas_station` reads as a gas station (not a station) and `bus_stop` as a bus.
const Map<String, IconData> _icons = <String, IconData>{
  // Public transport ------------------------------------------------------
  'bus': PhosphorIconsRegular.bus,
  'coach': PhosphorIconsRegular.bus,
  'tram': PhosphorIconsRegular.tram,
  'subway': PhosphorIconsRegular.subway,
  'metro': PhosphorIconsRegular.subway,
  'train': PhosphorIconsRegular.train,
  'rail': PhosphorIconsRegular.train,
  'railway': PhosphorIconsRegular.train,
  'station': PhosphorIconsRegular.train,
  'halt': PhosphorIconsRegular.train,
  'platform': PhosphorIconsRegular.train,
  'ferry': PhosphorIconsRegular.boat,
  'boat': PhosphorIconsRegular.boat,
  'dock': PhosphorIconsRegular.boat,
  'harbour': PhosphorIconsRegular.anchor,
  'harbor': PhosphorIconsRegular.anchor,
  'marina': PhosphorIconsRegular.anchor,
  'port': PhosphorIconsRegular.anchor,
  'airport': PhosphorIconsRegular.airplane,
  'aerodrome': PhosphorIconsRegular.airplane,
  'aeroway': PhosphorIconsRegular.airplane,
  'helipad': PhosphorIconsRegular.airplane,
  'heliport': PhosphorIconsRegular.airplane,
  'taxi': PhosphorIconsRegular.taxi,
  'car': PhosphorIconsRegular.car,
  'vehicle': PhosphorIconsRegular.car,
  'parking': PhosphorIconsRegular.car,
  'bicycle': PhosphorIconsRegular.bicycle,
  'bike': PhosphorIconsRegular.bicycle,
  'motorcycle': PhosphorIconsRegular.motorcycle,
  'moped': PhosphorIconsRegular.motorcycle,
  'truck': PhosphorIconsRegular.truck,
  'van': PhosphorIconsRegular.van,
  'cable': PhosphorIconsRegular.cableCar,
  'gondola': PhosphorIconsRegular.cableCar,
  'aerialway': PhosphorIconsRegular.cableCar,
  'charging': PhosphorIconsRegular.chargingStation,
  'fuel': PhosphorIconsRegular.gasPump,
  'gas': PhosphorIconsRegular.gasPump,
  'petrol': PhosphorIconsRegular.gasPump,

  // Food & drink ----------------------------------------------------------
  'restaurant': PhosphorIconsRegular.forkKnife,
  'food': PhosphorIconsRegular.forkKnife,
  'dining': PhosphorIconsRegular.forkKnife,
  'cafe': PhosphorIconsRegular.coffee,
  'coffee': PhosphorIconsRegular.coffee,
  'bakery': PhosphorIconsRegular.bread,
  'bar': PhosphorIconsRegular.martini,
  'pub': PhosphorIconsRegular.beerStein,
  'beer': PhosphorIconsRegular.beerStein,
  'biergarten': PhosphorIconsRegular.beerStein,
  'brewery': PhosphorIconsRegular.beerStein,
  'wine': PhosphorIconsRegular.wine,
  'ice': PhosphorIconsRegular.iceCream,
  'cream': PhosphorIconsRegular.iceCream,
  'pizza': PhosphorIconsRegular.pizza,
  'hamburger': PhosphorIconsRegular.hamburger,
  'burger': PhosphorIconsRegular.hamburger,
  'bbq': PhosphorIconsRegular.campfire,
  'tea': PhosphorIconsRegular.teaBag,
  'cake': PhosphorIconsRegular.cake,
  'dessert': PhosphorIconsRegular.cake,
  'confectionery': PhosphorIconsRegular.cake,

  // Shops -----------------------------------------------------------------
  'supermarket': PhosphorIconsRegular.shoppingCart,
  'grocery': PhosphorIconsRegular.shoppingCart,
  'groceries': PhosphorIconsRegular.shoppingCart,
  'convenience': PhosphorIconsRegular.shoppingCart,
  'shop': PhosphorIconsRegular.storefront,
  'shopping': PhosphorIconsRegular.storefront,
  'store': PhosphorIconsRegular.storefront,
  'mall': PhosphorIconsRegular.storefront,
  'marketplace': PhosphorIconsRegular.storefront,
  'clothes': PhosphorIconsRegular.tShirt,
  'clothing': PhosphorIconsRegular.tShirt,
  'boutique': PhosphorIconsRegular.tShirt,
  'fashion': PhosphorIconsRegular.tShirt,
  'books': PhosphorIconsRegular.books,
  'bookshop': PhosphorIconsRegular.books,
  'newsagent': PhosphorIconsRegular.newspaper,
  'florist': PhosphorIconsRegular.flower,
  'hairdresser': PhosphorIconsRegular.scissors,
  'beauty': PhosphorIconsRegular.scissors,
  'optician': PhosphorIconsRegular.eyeglasses,
  'electronics': PhosphorIconsRegular.deviceMobile,
  'mobile': PhosphorIconsRegular.deviceMobile,
  'furniture': PhosphorIconsRegular.armchair,
  'laundry': PhosphorIconsRegular.washingMachine,
  'toys': PhosphorIconsRegular.puzzlePiece,

  // Health ----------------------------------------------------------------
  'hospital': PhosphorIconsRegular.hospital,
  'clinic': PhosphorIconsRegular.hospital,
  'doctor': PhosphorIconsRegular.stethoscope,
  'doctors': PhosphorIconsRegular.stethoscope,
  'physician': PhosphorIconsRegular.stethoscope,
  'dentist': PhosphorIconsRegular.tooth,
  'veterinary': PhosphorIconsRegular.pawPrint,
  'vet': PhosphorIconsRegular.pawPrint,
  'pharmacy': PhosphorIconsRegular.pill,
  'chemist': PhosphorIconsRegular.pill,
  'drugstore': PhosphorIconsRegular.pill,
  'medical': PhosphorIconsRegular.firstAid,

  // Civic & public service ------------------------------------------------
  'bank': PhosphorIconsRegular.bank,
  'atm': PhosphorIconsRegular.money,
  'money': PhosphorIconsRegular.money,
  'currency': PhosphorIconsRegular.money,
  'bureau': PhosphorIconsRegular.money,
  'post': PhosphorIconsRegular.envelope,
  'mail': PhosphorIconsRegular.envelope,
  'police': PhosphorIconsRegular.policeCar,
  'fire': PhosphorIconsRegular.fireTruck,
  'library': PhosphorIconsRegular.books,
  'school': PhosphorIconsRegular.graduationCap,
  'college': PhosphorIconsRegular.graduationCap,
  'university': PhosphorIconsRegular.graduationCap,
  'kindergarten': PhosphorIconsRegular.graduationCap,
  'academy': PhosphorIconsRegular.graduationCap,
  'education': PhosphorIconsRegular.graduationCap,
  'church': PhosphorIconsRegular.church,
  'chapel': PhosphorIconsRegular.church,
  'cathedral': PhosphorIconsRegular.church,
  'temple': PhosphorIconsRegular.church,
  'worship': PhosphorIconsRegular.church,
  'mosque': PhosphorIconsRegular.mosque,
  'synagogue': PhosphorIconsRegular.synagogue,
  'museum': PhosphorIconsRegular.buildings,
  'courthouse': PhosphorIconsRegular.gavel,
  'townhall': PhosphorIconsRegular.bank,

  // Lodging & leisure -----------------------------------------------------
  'hotel': PhosphorIconsRegular.bed,
  'hostel': PhosphorIconsRegular.bed,
  'motel': PhosphorIconsRegular.bed,
  'guesthouse': PhosphorIconsRegular.bed,
  'camp': PhosphorIconsRegular.tent,
  'campsite': PhosphorIconsRegular.tent,
  'cinema': PhosphorIconsRegular.filmReel,
  'movie': PhosphorIconsRegular.filmReel,
  'theatre': PhosphorIconsRegular.ticket,
  'theater': PhosphorIconsRegular.ticket,
  'nightclub': PhosphorIconsRegular.martini,
  'casino': PhosphorIconsRegular.diceFive,
  'gambling': PhosphorIconsRegular.diceFive,
  'gym': PhosphorIconsRegular.barbell,
  'fitness': PhosphorIconsRegular.barbell,
  'sports': PhosphorIconsRegular.barbell,
  'stadium': PhosphorIconsRegular.trophy,
  'swimming': PhosphorIconsRegular.swimmingPool,
  'pool': PhosphorIconsRegular.swimmingPool,
  'golf': PhosphorIconsRegular.golf,
  'tennis': PhosphorIconsRegular.tennisBall,
  'soccer': PhosphorIconsRegular.soccerBall,
  'football': PhosphorIconsRegular.football,
  'basketball': PhosphorIconsRegular.basketball,
  'bowling': PhosphorIconsRegular.bowlingBall,
  'park': PhosphorIconsRegular.tree,
  'garden': PhosphorIconsRegular.tree,
  'forest': PhosphorIconsRegular.tree,
  'nature': PhosphorIconsRegular.tree,
  'beach': PhosphorIconsRegular.umbrella,
  'viewpoint': PhosphorIconsRegular.binoculars,
  'attraction': PhosphorIconsRegular.camera,
  'castle': PhosphorIconsRegular.castleTurret,
  'lighthouse': PhosphorIconsRegular.lighthouse,
  'zoo': PhosphorIconsRegular.pawPrint,
  'aquarium': PhosphorIconsRegular.fish,
  'pet': PhosphorIconsRegular.pawPrint,
  'dog': PhosphorIconsRegular.pawPrint,
  'fountain': PhosphorIconsRegular.drop,
  'toilet': PhosphorIconsRegular.toilet,
  'toilets': PhosphorIconsRegular.toilet,
  'restroom': PhosphorIconsRegular.toilet,
  'shower': PhosphorIconsRegular.shower,
};

/// Lower-cases [category], drops everything that is not a letter or digit and
/// collapses the separators to single spaces, so `train_station`, `Train
/// Station` and `train-station` all tokenise the same.
String _normalise(String? category) {
  if (category == null) {
    return '';
  }
  return category.toLowerCase().replaceAll(_separators, ' ').trim();
}

final RegExp _separators = RegExp(r'[^a-z0-9]+');
