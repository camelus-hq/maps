import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/core/theme/app_theme.dart';
import 'package:openmaps/data/fakes/fake_external_actions.dart';
import 'package:openmaps/data/fakes/fake_osm_place_source.dart';
import 'package:openmaps/data/fakes/fake_review_service.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/features/place_details/widgets/place_details_sheet.dart';
import 'package:openmaps/features/reviews/widgets/star_rating.dart';
import 'package:openmaps/state/place.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/reviews.dart';
import 'package:openmaps/state/settings.dart';
import 'package:openmaps/state/social.dart';

/// The place sheet: the rating / "Write a review" line, the Overview facts from
/// OpenStreetMap (contact + wheelchair + hours) and the Reviews tab.
void main() {
  const Place unreviewed = Place(
    id: 'node/111',
    name: 'Willow Park',
    position: LatLon(52.5150, 13.4030),
  );
  const Place reviewed = Place(
    id: 'sample-harbour-coffee',
    name: 'Harbour Coffee',
    position: LatLon(52.5210, 13.4075),
    category: 'Cafe',
    address: '1 Lantern Way',
  );

  late FakeExternalActions external;
  late FakeOsmPlaceSource osm;

  ProviderContainer container() {
    return ProviderContainer(
      overrides: <Override>[
        reviewServiceProvider.overrideWithValue(FakeReviewService()),
        socialServiceProvider.overrideWithValue(FakeSocialService()),
        osmPlaceSourceProvider.overrideWithValue(osm),
        externalActionsProvider.overrideWithValue(external),
      ],
    );
  }

  setUp(() {
    external = FakeExternalActions();
    osm = FakeOsmPlaceSource();
  });

  Future<void> pump(
    WidgetTester tester,
    ProviderContainer c,
    Place place,
  ) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await c.read(friendsProvider.future);
    c.read(selectedPlaceProvider.notifier).select(place);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: PlaceDetailsSheet(place: place)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Expands the draggable sheet so the tab body is laid out.
  Future<void> expand(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
  }

  testWidgets('an unreviewed place offers a "Write a review" button', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    await pump(tester, c, unreviewed);

    expect(find.text('Write a review'), findsOneWidget);
    expect(find.byType(StarRating), findsNothing);

    await tester.tap(find.text('Write a review'));
    await tester.pumpAndSettle();
    expect(c.read(reviewComposerProvider).isOpen, isTrue);
    expect(c.read(reviewComposerProvider).place?.id, unreviewed.id);
  });

  testWidgets('the peek shows the same summary, folded below the actions', (
    WidgetTester tester,
  ) async {
    // A place with the promoted-payment badges — the tallest summary — so the
    // peek is sized for the worst case.
    osm.seed(
      unreviewed.id,
      const Place(
        id: 'node/111',
        name: 'Willow Park',
        position: LatLon(52.5150, 13.4030),
        openingHours: '24/7',
        osmTags: <String, String>{'payment:lightning': 'yes'},
      ),
    );
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    await pump(tester, c, unreviewed);

    // Default (half): name, rating, actions and the summary + tabs.
    expect(find.text('Willow Park'), findsOneWidget);
    expect(find.text('Bitcoin Lightning'), findsOneWidget);
    expect(find.text('Open now'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);

    // Pulled down to the peek the same summary stays — the badges, the hours
    // status and the action pills — folded just below the actions; the tabs
    // drop below the fold.
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.text('Willow Park'), findsOneWidget);
    expect(find.text('Bitcoin Lightning'), findsOneWidget);
    expect(find.text('Open now'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
  });

  testWidgets('a reviewed place shows the rating and the friend headline', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    await pump(tester, c, reviewed);

    expect(find.byType(StarRating), findsOneWidget);
    expect(find.text('(3)'), findsOneWidget);
    expect(find.text('Write a review'), findsNothing);

    await expand(tester);
    await tester.tap(find.text('Reviews'));
    await tester.pumpAndSettle();
    // The friend's review is the headline (ReviewSummary prefers it).
    expect(
      find.textContaining('Best flat white in the neighbourhood'),
      findsOneWidget,
    );
    expect(find.text('Recommended by your friends'), findsOneWidget);
  });

  testWidgets('shows OpenStreetMap contact facts and wheelchair access', (
    WidgetTester tester,
  ) async {
    osm.seed(
      unreviewed.id,
      const Place(
        id: 'node/111',
        name: 'Willow Park',
        position: LatLon(52.5150, 13.4030),
        address: 'Leberstraße 21, 10829 Berlin',
        phone: '030 53166994',
        email: 'hi@willow.example',
        website: 'instagram.com/willow',
        wheelchairAccessible: true,
        openingHours: 'Mo-Fr 08:00-18:00',
      ),
    );
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    await pump(tester, c, unreviewed);
    await expand(tester);

    expect(find.text('Leberstraße 21, 10829 Berlin'), findsOneWidget);
    expect(find.text('030 53166994'), findsOneWidget);
    expect(find.text('instagram.com/willow'), findsOneWidget);
    expect(find.text('hi@willow.example'), findsOneWidget);
    expect(find.text('Wheelchair accessible'), findsOneWidget);
    expect(find.byIcon(Icons.accessible), findsOneWidget);
    // The general weekly hours (all days) sit in the Overview.
    expect(find.text('Opening hours'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);

    await tester.tap(find.text('030 53166994'));
    await tester.pumpAndSettle();
    expect(external.calls, <String>['030 53166994']);
  });

  testWidgets('shows explicit unavailable wheelchair and payment states', (
    WidgetTester tester,
  ) async {
    osm.seed(
      unreviewed.id,
      const Place(
        id: 'node/111',
        name: 'Willow Park',
        position: LatLon(52.5150, 13.4030),
        wheelchairAccessible: false,
        osmTags: <String, String>{'payment:cash': 'no'},
      ),
    );
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    await pump(tester, c, unreviewed);
    await expand(tester);

    expect(find.text('Not wheelchair accessible'), findsOneWidget);
    expect(find.byIcon(Icons.not_accessible), findsOneWidget);
    expect(find.text('Payment'), findsNothing);
    expect(find.byTooltip('Cash'), findsNothing);
  });

  testWidgets('the Call pill is disabled without a phone number', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    await pump(tester, c, unreviewed);

    final Finder callPill = find.text('Call');
    expect(callPill, findsOneWidget);
    await tester.tap(callPill, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(external.calls, isEmpty);
  });

  testWidgets('the Website pill opens the place website instead of Nearby', (
    WidgetTester tester,
  ) async {
    osm.seed(
      unreviewed.id,
      const Place(
        id: 'node/111',
        name: 'Willow Park',
        position: LatLon(52.5150, 13.4030),
        website: 'https://willow.example',
      ),
    );
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    await pump(tester, c, unreviewed);

    expect(find.text('Website'), findsOneWidget);
    expect(find.text('Nearby'), findsNothing);
    await tester.ensureVisible(find.text('Website'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Website'));
    await tester.pumpAndSettle();
    expect(external.websites, <String>['https://willow.example']);
  });

  testWidgets('a 24/7 place reads as "Open now"', (WidgetTester tester) async {
    osm.seed(
      unreviewed.id,
      const Place(
        id: 'node/111',
        name: 'Willow Park',
        position: LatLon(52.5150, 13.4030),
        openingHours: '24/7',
      ),
    );
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    await pump(tester, c, unreviewed);
    await expand(tester);
    expect(find.text('Open now'), findsOneWidget);
  });

  testWidgets('an unreadable hours tag is shown verbatim', (
    WidgetTester tester,
  ) async {
    osm.seed(
      unreviewed.id,
      const Place(
        id: 'node/111',
        name: 'Willow Park',
        position: LatLon(52.5150, 13.4030),
        openingHours: 'by appointment',
      ),
    );
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    await pump(tester, c, unreviewed);
    await expand(tester);
    expect(find.text('by appointment'), findsOneWidget);
  });

  testWidgets('lists only the accepted payments, with icon tooltips', (
    WidgetTester tester,
  ) async {
    osm.seed(
      unreviewed.id,
      const Place(
        id: 'node/111',
        name: 'Willow Park',
        position: LatLon(52.5150, 13.4030),
        osmTags: <String, String>{
          'payment:cash': 'yes',
          'payment:visa': 'yes',
          'payment:girocard': 'only',
          'payment:american_express': 'no',
        },
      ),
    );
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    await pump(tester, c, unreviewed);
    await expand(tester);

    expect(find.text('Payment'), findsOneWidget);
    expect(find.byTooltip('Cash'), findsOneWidget);
    expect(find.byTooltip('Visa'), findsOneWidget);
    expect(find.byTooltip('Girocard (only)'), findsOneWidget);
    // Declined methods are never shown.
    expect(find.byTooltip('American Express'), findsNothing);
  });

  testWidgets('shows card methods explicitly marked as not accepted', (
    WidgetTester tester,
  ) async {
    osm.seed(
      unreviewed.id,
      const Place(
        id: 'node/111',
        name: 'Willow Park',
        position: LatLon(52.5150, 13.4030),
        osmTags: <String, String>{
          'payment:cards': 'no',
          'payment:credit_cards': 'no',
          'payment:debit_cards': 'no',
        },
      ),
    );
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    await pump(tester, c, unreviewed);
    await expand(tester);

    expect(
      find.text('Not accepted: Cards, Credit cards, Debit cards'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.credit_card_off), findsOneWidget);
  });

  testWidgets('promotes Lightning and Cashu below the review', (
    WidgetTester tester,
  ) async {
    osm.seed(
      unreviewed.id,
      const Place(
        id: 'node/111',
        name: 'Willow Park',
        position: LatLon(52.5150, 13.4030),
        osmTags: <String, String>{
          'payment:lightning': 'yes',
          'payment:cashu': 'yes',
          'payment:bitcoin': 'yes',
        },
      ),
    );
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    await pump(tester, c, unreviewed);
    await expand(tester);

    // The badges sit above the tabs (right below the rating / review area).
    expect(find.text('Bitcoin Lightning'), findsOneWidget);
    expect(find.text('Cashu'), findsOneWidget);
    // Plain Bitcoin is not promoted — only listed among the payments.
    expect(find.byTooltip('Bitcoin'), findsOneWidget);
  });

  testWidgets('shows wheelchair notes, takeaway and a payment note', (
    WidgetTester tester,
  ) async {
    osm.seed(
      unreviewed.id,
      const Place(
        id: 'node/111',
        name: 'Willow Park',
        position: LatLon(52.5150, 13.4030),
        osmTags: <String, String>{
          'wheelchair:description': 'Step at the entrance',
          'takeaway': 'only',
          'description:payment': 'Cards only over 5 EUR',
        },
      ),
    );
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    await pump(tester, c, unreviewed);
    await expand(tester);

    expect(find.text('Step at the entrance'), findsOneWidget);
    expect(find.text('Takeaway only'), findsOneWidget);
    expect(find.text('Cards only over 5 EUR'), findsOneWidget);
  });

  testWidgets('the Photos tab shows the OSM image', (
    WidgetTester tester,
  ) async {
    osm.seed(
      unreviewed.id,
      const Place(
        id: 'node/111',
        name: 'Willow Park',
        position: LatLon(52.5150, 13.4030),
        osmTags: <String, String>{'image': 'https://example.org/willow.jpg'},
      ),
    );
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    await pump(tester, c, unreviewed);
    await expand(tester);

    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();

    // In tests the image cannot load, so the honest fallback is shown instead of
    // the empty state — the photo slot is populated.
    expect(find.text('Photo from OpenStreetMap'), findsOneWidget);
    expect(find.text('No photos yet'), findsNothing);
  });

  testWidgets('the developer option lists every raw OSM tag', (
    WidgetTester tester,
  ) async {
    osm.seed(
      unreviewed.id,
      const Place(
        id: 'node/111',
        name: 'Willow Park',
        position: LatLon(52.5150, 13.4030),
        osmTags: <String, String>{
          'payment:cash': 'yes',
          'takeaway': 'yes',
          'check_date': '2025-09-27',
        },
      ),
    );
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    // Before enabling the option the raw keys are hidden.
    await pump(tester, c, unreviewed);
    await expand(tester);
    expect(find.textContaining('OpenStreetMap tags'), findsNothing);

    // Enable it and re-pump; the tags appear.
    await c.read(settingsProvider.notifier).setShowOsmTags(true);
    await tester.pumpAndSettle();
    expect(find.text('OpenStreetMap tags (3)'), findsOneWidget);
    expect(find.text('check_date'), findsOneWidget);
    expect(find.text('2025-09-27'), findsOneWidget);
  });
}
