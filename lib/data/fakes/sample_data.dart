import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/place.dart';

/// Synthetic data used by the fakes.
///
/// Names and addresses are invented and the coordinates sit in a neutral area;
/// nothing here derives from Google data. Replace with real adapters later.
abstract final class SampleData {
  /// Neutral origin used by the fake camera/location services.
  static const LatLon origin = LatLon(52.5200, 13.4050);

  static const List<Place> places = <Place>[
    Place(
      id: 'sample-harbour-coffee',
      name: 'Harbour Coffee',
      position: LatLon(52.5210, 13.4075),
      category: 'Cafe',
      address: '1 Lantern Way',
    ),
    Place(
      id: 'sample-old-mill-cafe',
      name: 'Old Mill Cafe',
      position: LatLon(52.5180, 13.4020),
      category: 'Cafe',
      address: '4 Miller Street',
    ),
    Place(
      id: 'sample-riverside-kitchen',
      name: 'Riverside Kitchen',
      position: LatLon(52.5230, 13.4100),
      category: 'Restaurant',
      address: '12 Embankment Road',
    ),
    Place(
      id: 'sample-northgate-fuel',
      name: 'Northgate Fuel',
      position: LatLon(52.5260, 13.4010),
      category: 'Gas',
      address: '88 Northgate',
    ),
    Place(
      id: 'sample-green-market',
      name: 'Green Market',
      position: LatLon(52.5175, 13.4090),
      category: 'Groceries',
      address: '5 Market Square',
    ),
    Place(
      id: 'sample-station-hotel',
      name: 'Station Hotel',
      position: LatLon(52.5250, 13.4060),
      category: 'Hotel',
      address: '2 Platform Street',
    ),
    Place(
      id: 'sample-willow-park',
      name: 'Willow Park',
      position: LatLon(52.5150, 13.4030),
      category: 'Park',
      address: 'Willow Park',
    ),
    Place(
      id: 'sample-city-library',
      name: 'City Library',
      position: LatLon(52.5195, 13.4120),
      category: 'Library',
      address: '9 Reading Lane',
    ),
  ];
}
