import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/core/theme/app_theme.dart';
import 'package:openmaps/data/fakes/fake_review_service.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/entities/review_marker.dart';
import 'package:openmaps/features/map_home/widgets/friend_review_chip.dart';
import 'package:openmaps/features/reviews/widgets/place_reviews_section.dart';
import 'package:openmaps/features/reviews/widgets/write_review_sheet.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/reviews.dart';
import 'package:openmaps/state/social.dart';

/// Goldens for the review UI (composer + place reviews). Regression policy is
/// the same as `screens_golden_test.dart`: an intentional change updates the
/// golden in the same commit; never hide a regression.
void main() {
  const Place coffee = Place(
    id: 'sample-harbour-coffee',
    name: 'Harbour Coffee',
    position: LatLon(52.5210, 13.4075),
    category: 'Cafe',
    address: '1 Lantern Way',
  );

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: <Override>[
        reviewServiceProvider.overrideWithValue(FakeReviewService()),
        socialServiceProvider.overrideWithValue(FakeSocialService()),
      ],
    );
  });

  tearDown(() => container.dispose());

  void setSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('write review sheet matches the golden', (
    WidgetTester tester,
  ) async {
    setSurface(tester);
    container.read(reviewComposerProvider.notifier).open(coffee);
    container.read(reviewComposerProvider.notifier).setStars(5);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: WriteReviewSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/write_review.png'),
    );
  });

  testWidgets('place reviews section matches the golden', (
    WidgetTester tester,
  ) async {
    setSurface(tester);
    await container.read(friendsProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlaceReviewsSection(place: coffee),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/place_reviews.png'),
    );
  });

  testWidgets('friend review map chip matches the golden', (
    WidgetTester tester,
  ) async {
    setSurface(tester);
    // The chip is a pure view of the friend-review markers; the pipeline that
    // produces them is covered by the state tests, so the golden pins the
    // marker list directly.
    final ProviderContainer local = ProviderContainer(
      overrides: <Override>[
        friendReviewMarkersProvider.overrideWithValue(<ReviewMarker>[
          const ReviewMarker(
            placeKey: 'openstreetmap:node/2764050762',
            position: LatLon(52.5195, 13.4120),
            averageRating: 0.96,
            reviewCount: 5,
            friendCount: 3,
            topFriendName: 'Mia',
          ),
          const ReviewMarker(
            placeKey: 'openstreetmap:way/123',
            position: LatLon(52.5220, 13.4090),
            averageRating: 0.8,
            reviewCount: 2,
            friendCount: 1,
            topFriendName: 'Timo',
          ),
        ]),
      ],
    );
    addTearDown(local.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: local,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: Center(child: FriendReviewChip())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/friend_review_chip.png'),
    );
  });
}
