import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/theme/app_theme.dart';
import 'package:openmaps/data/fakes/fake_review_service.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/features/reviews/widgets/star_rating.dart';
import 'package:openmaps/features/reviews/widgets/write_review_sheet.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/reviews.dart';

void main() {
  const Place place = Place(
    id: 'sample-harbour-coffee',
    name: 'Berlin State Opera',
    position: LatLon(52.5210, 13.4075),
    category: 'Opera house',
    address: 'Mitte, Berlin',
  );

  late FakeReviewService reviews;
  late ProviderContainer container;

  setUp(() {
    reviews = FakeReviewService();
    container = ProviderContainer(
      overrides: <Override>[
        reviewServiceProvider.overrideWithValue(reviews),
        socialServiceProvider.overrideWithValue(FakeSocialService()),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpComposer(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container.read(reviewComposerProvider.notifier).open(place);
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
  }

  testWidgets('renders the composer with the place and the review fields', (
    WidgetTester tester,
  ) async {
    await pumpComposer(tester);
    expect(find.text('Berlin State Opera'), findsOneWidget);
    expect(find.text('How was your visit?'), findsOneWidget);
    expect(find.text('Your review'), findsOneWidget);
    expect(find.text('Add photos'), findsOneWidget);
    expect(find.text('Public review'), findsOneWidget);
    expect(find.text('Publish review'), findsOneWidget);
    expect(find.text('You can edit your review anytime.'), findsOneWidget);
  });

  testWidgets('tapping a star sets the rating and its label', (
    WidgetTester tester,
  ) async {
    await pumpComposer(tester);
    final Finder stars = find.descendant(
      of: find.byType(StarRatingInput),
      matching: find.byType(InkResponse),
    );
    expect(stars, findsNWidgets(5));
    await tester.tap(stars.at(4));
    await tester.pump();
    expect(find.text('Excellent'), findsOneWidget);
    expect(find.text('5 out of 5'), findsOneWidget);
    expect(container.read(reviewComposerProvider).stars, 5);
  });

  testWidgets('typing a review enables publishing and publishes it', (
    WidgetTester tester,
  ) async {
    await pumpComposer(tester);
    await tester.tap(
      find
          .descendant(
            of: find.byType(StarRatingInput),
            matching: find.byType(InkResponse),
          )
          .at(3),
    );
    await tester.enterText(
      find.byType(TextField),
      'An unforgettable evening. The acoustics are incredible.',
    );
    await tester.pump();

    final FilledButton button = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.text('Publish review'));
    await tester.pumpAndSettle();

    expect(reviews.published, hasLength(1));
    expect(reviews.published.single.text, contains('unforgettable'));
    expect(container.read(reviewComposerProvider).isOpen, isFalse);
    expect(find.text('Review published'), findsOneWidget);
  });

  testWidgets('choosing friends-only disables publishing with a note', (
    WidgetTester tester,
  ) async {
    await pumpComposer(tester);
    await tester.tap(find.text('Public review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share with friends'));
    await tester.pumpAndSettle();

    expect(find.text('Share with friends'), findsOneWidget);
    expect(find.text('Only your friends can see this review.'), findsOneWidget);
    expect(
      find.text('Friends-only reviews are not available yet.'),
      findsOneWidget,
    );
    final FilledButton button = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('publishing without a rating or text is disabled', (
    WidgetTester tester,
  ) async {
    await pumpComposer(tester);
    final FilledButton button = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(button.onPressed, isNull);
  });
}
