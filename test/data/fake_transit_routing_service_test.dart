import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/fake_transit_routing_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/transit.dart';

void main() {
  const LatLon origin = LatLon(52.52, 13.4);
  const LatLon destination = LatLon(52.5, 13.3);

  test('builds two journeys with a transfer, realtime and platforms', () async {
    final FakeTransitRoutingService service = FakeTransitRoutingService(
      now: DateTime.utc(2026, 5, 1, 9),
    );
    final List<TransitItinerary> itineraries = await service.plan(
      const TransitQuery(origin: origin, destination: destination),
    );

    expect(itineraries, hasLength(2));
    final TransitItinerary first = itineraries.first;
    expect(first.rides, hasLength(1));
    expect(first.transfers, 0);
    expect(first.hasRealtime, isTrue);
    expect(first.departureDelay, const Duration(minutes: 1));

    final TransitItinerary second = itineraries[1];
    expect(second.rides, hasLength(2));
    expect(second.transfers, 1);
    // The change has a boarding platform on each ride.
    expect(second.rides.first.from.hasTrack, isTrue);
    expect(second.rides.last.from.hasTrack, isTrue);
  });

  test(
    'a multi-stop journey is one chained itinerary through the stops',
    () async {
      final FakeTransitRoutingService service = FakeTransitRoutingService(
        now: DateTime.utc(2026, 5, 1, 9),
      );
      final List<TransitItinerary> itineraries = await service.plan(
        const TransitQuery(
          origin: origin,
          destination: destination,
          stops: <LatLon>[LatLon(52.51, 13.35)],
        ),
      );

      expect(itineraries, hasLength(1));
      // Two segments, each a walk + a ride.
      expect(itineraries.first.rides, hasLength(2));
      expect(itineraries.first.transfers, 1);
    },
  );

  test('numItineraries caps the result', () async {
    final FakeTransitRoutingService service = FakeTransitRoutingService(
      now: DateTime.utc(2026, 5, 1, 9),
      numItineraries: 1,
    );
    final List<TransitItinerary> itineraries = await service.plan(
      const TransitQuery(origin: origin, destination: destination),
    );
    expect(itineraries, hasLength(1));
  });
}
