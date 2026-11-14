import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/core/theme/app_theme.dart';
import 'package:openmaps/data/fakes/fake_review_service.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/features/reviews/widgets/place_reviews_section.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/reviews.dart';
import 'package:openmaps/state/social.dart';

void main() {
  const Place coffee = Place(
    id: 'sample-harbour-coffee',
    name: 'Harbour Coffee',
    position: LatLon(52.5210, 13.4075),
    category: 'Cafe',
  );
  const Place unreviewed = Place(
    id: 'sample-willow-park',
    name: 'Willow Park',
    position: LatLon(52.5150, 13.4030),
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

  Future<void> pumpSection(WidgetTester tester, Place place) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await container.read(friendsProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlaceReviewsSection(place: place),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the friend banner, headline review and friend badge', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester, coffee);
    expect(find.text('Reviews'), findsOneWidget);
    expect(find.text('Recommended by your friends'), findsOneWidget);
    expect(find.text('2 friends have reviewed this place'), findsOneWidget);
    expect(
      find.textContaining('Best flat white in the neighbourhood'),
      findsOneWidget,
    );
    expect(find.text('Friend'), findsWidgets);
    expect(find.text('Write a review'), findsOneWidget);
    expect(find.text('Be the first to review'), findsNothing);
  });

  testWidgets('the banner filters down to friend reviews', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester, coffee);
    await tester.tap(find.text('Recommended by your friends'));
    await tester.pumpAndSettle();
    expect(find.text('Showing your friends’ reviews'), findsOneWidget);
    // The non-friend review ("Solid coffee and pastries.") is filtered out.
    expect(find.textContaining('Solid coffee and pastries'), findsNothing);
  });

  testWidgets('an unreviewed place offers to be first', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester, unreviewed);
    expect(find.text('No reviews yet'), findsOneWidget);
    expect(find.text('Be the first to review'), findsOneWidget);
    expect(find.text('Recommended by your friends'), findsNothing);
  });

  testWidgets('"Write a review" opens the composer through the command', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester, coffee);
    await tester.tap(find.text('Write a review'));
    await tester.pumpAndSettle();
    expect(container.read(reviewComposerProvider).isOpen, isTrue);
    expect(container.read(reviewComposerProvider).place?.id, coffee.id);
  });
}
