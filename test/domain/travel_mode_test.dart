import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';

/// The distance-based default mode for a freshly opened directions sheet.
void main() {
  test('suggestedForDistance maps each band to a travel mode', () {
    // Under 2 km → walking.
    expect(TravelMode.suggestedForDistance(0), TravelMode.walk);
    expect(TravelMode.suggestedForDistance(1999), TravelMode.walk);
    // 2–9 km → cycling.
    expect(TravelMode.suggestedForDistance(2000), TravelMode.cycle);
    expect(TravelMode.suggestedForDistance(8999), TravelMode.cycle);
    // 9–20 km → public transport.
    expect(TravelMode.suggestedForDistance(9000), TravelMode.transit);
    expect(TravelMode.suggestedForDistance(19999), TravelMode.transit);
    // 20 km and over → driving.
    expect(TravelMode.suggestedForDistance(20000), TravelMode.drive);
    expect(TravelMode.suggestedForDistance(50000), TravelMode.drive);
  });
}
