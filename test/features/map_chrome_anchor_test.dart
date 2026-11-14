import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/app/app.dart';
import 'package:openmaps/core/theme/app_spacing.dart';
import 'package:openmaps/data/fakes/fake_external_actions.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/lat_lon_bounds.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/ports/search_service.dart';
import 'package:openmaps/features/map_home/widgets/map_attribution.dart';
import 'package:openmaps/features/map_home/widgets/map_controls.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/search.dart';
import 'package:openmaps/state/sheet_anchor.dart';

/// A browse that never completes, so the category sheet stays in its loading
/// state while the test inspects the chrome.
class _SlowSearch implements SearchService {
  final Completer<List<Place>> _completer = Completer<List<Place>>();

  @override
  Future<List<Place>> search(
    String query, {
    LatLon? proximity,
    LatLonBounds? bounds,
  }) async => const <Place>[];

  @override
  Future<List<Place>> nearbyCategory(
    String categoryId, {
    required LatLon proximity,
    LatLonBounds? bounds,
    int limit = 10,
  }) => _completer.future;
}

/// A controller that starts on a fixed anchor, so the floating chrome can be
/// tested without driving a real sheet.
class _FixedAnchor extends SheetAnchorController {
  _FixedAnchor(this.initial);

  final SheetAnchor? initial;

  @override
  SheetAnchor? build() => initial;
}

Widget _harness(
  SheetAnchor? anchor,
  Widget child, {
  FakeExternalActions? externalActions,
}) {
  return ProviderScope(
    overrides: <Override>[
      sheetAnchorProvider.overrideWith(() => _FixedAnchor(anchor)),
      if (externalActions != null)
        externalActionsProvider.overrideWith((Ref ref) => externalActions),
    ],
    child: MaterialApp(
      home: Scaffold(body: Stack(children: <Widget>[child])),
    ),
  );
}

AnimatedOpacity _opacityOf(WidgetTester tester, Finder root) {
  return tester.widget<AnimatedOpacity>(
    find.descendant(of: root, matching: find.byType(AnimatedOpacity)),
  );
}

Positioned _positionedOf(WidgetTester tester, Finder root) {
  return tester.widget<Positioned>(
    find.descendant(of: root, matching: find.byType(Positioned)),
  );
}

void main() {
  testWidgets('controls attach just above the sheet and stay opaque', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        const SheetAnchor(topInset: 120, fraction: 0.2),
        const MapControls(),
      ),
    );
    await tester.pumpAndSettle();

    final Finder controls = find.byType(MapControls);
    expect(_positionedOf(tester, controls).bottom, 120 + AppSpacing.md);
    expect(_opacityOf(tester, controls).opacity, 1);
  });

  testWidgets('controls fade out once the sheet is tall enough', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        const SheetAnchor(topInset: 640, fraction: 0.8),
        const MapControls(),
      ),
    );
    await tester.pumpAndSettle();

    expect(_opacityOf(tester, find.byType(MapControls)).opacity, 0);
  });

  testWidgets('controls stay visible at the 0.5 sheet position', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        const SheetAnchor(topInset: 400, fraction: 0.5),
        const MapControls(),
      ),
    );
    await tester.pumpAndSettle();

    expect(_opacityOf(tester, find.byType(MapControls)).opacity, 1);
  });

  testWidgets('controls stay hidden until a sheet has been measured', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_harness(null, const MapControls()));
    await tester.pumpAndSettle();

    expect(_opacityOf(tester, find.byType(MapControls)).opacity, 0);
  });

  testWidgets('attribution credits Mapbox and OpenStreetMap above the sheet', (
    WidgetTester tester,
  ) async {
    final FakeExternalActions externalActions = FakeExternalActions();
    await tester.pumpWidget(
      _harness(
        const SheetAnchor(topInset: 90, fraction: 0.2),
        const MapAttribution(),
        externalActions: externalActions,
      ),
    );
    await tester.pumpAndSettle();

    final Finder attribution = find.byType(MapAttribution);
    expect(find.text('Mapbox'), findsOneWidget);
    expect(find.text('OpenStreetMap'), findsOneWidget);
    expect(_positionedOf(tester, attribution).bottom, 90 + AppSpacing.xs);
    expect(_opacityOf(tester, attribution).opacity, 1);

    await tester.tap(find.text('Mapbox'));
    await tester.tap(find.text('OpenStreetMap'));
    expect(externalActions.websites, <String>[
      'https://www.mapbox.com/about/maps',
      'http://www.openstreetmap.org/about/',
    ]);
  });

  testWidgets('attribution fades out with a tall sheet', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        const SheetAnchor(topInset: 640, fraction: 0.8),
        const MapAttribution(),
      ),
    );
    await tester.pumpAndSettle();

    expect(_opacityOf(tester, find.byType(MapAttribution)).opacity, 0);
  });

  testWidgets('the visible sheet anchors the floating chrome', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The home sheet measured itself without a gesture and the chrome attached
    // to its top edge.
    final SheetAnchor? anchor = container.read(sheetAnchorProvider);
    expect(anchor, isNotNull);
    expect(anchor!.fraction, lessThan(kSheetChromeFadeThreshold));
    expect(anchor.topInset, greaterThan(0));

    final Finder controls = find.byType(MapControls);
    expect(
      _positionedOf(tester, controls).bottom,
      closeTo(anchor.topInset + AppSpacing.md, 0.01),
    );
    expect(_opacityOf(tester, controls).opacity, 1);
    // Keyless builds show the map placeholder, so there is no data attribution.
    expect(find.byType(MapAttribution), findsNothing);
  });

  testWidgets('the chrome follows the sheet within the same frame', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: OpenMapsApp()));
    await tester.pumpAndSettle();

    final Finder controls = find.byType(MapControls);
    double controlsBottom() => _positionedOf(tester, controls).bottom ?? 0;
    final double before = controlsBottom();

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.text('Explore').first),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, -150));
    // A single frame after the drag: the chrome must already be attached to the
    // sheet's new top edge, not one frame behind it.
    await tester.pump();
    final double afterOneFrame = controlsBottom();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(afterOneFrame - before, greaterThan(100));
  });

  testWidgets('closing a sheet re-anchors the chrome to the sheet below', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    final SheetAnchor home = container.read(sheetAnchorProvider)!;

    // Open a category sheet, then close it again (tap the chip twice). The
    // chrome must drop back onto the home sheet without a nudge.
    final Finder chip = find.widgetWithText(FilterChip, 'Cafes');
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(
      container.read(sheetAnchorProvider)!.fraction,
      greaterThan(home.fraction),
    );

    await tester.tap(chip);
    await tester.pumpAndSettle();
    final SheetAnchor back = container.read(sheetAnchorProvider)!;
    expect(back.fraction, closeTo(home.fraction, 0.001));
    expect(back.topInset, closeTo(home.topInset, 0.5));
  });

  testWidgets('opening the category results attaches the chrome at once', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Cafes'));
    await tester.pumpAndSettle();

    // The chrome must attach to the category sheet's real top edge immediately —
    // not a value measured mid-transition (the entry slide used to shift the
    // measured top edge, leaving the buttons low until the next sheet drag).
    final SheetAnchor anchor = container.read(sheetAnchorProvider)!;
    final Finder controls = find.byType(MapControls);
    expect(
      _positionedOf(tester, controls).bottom,
      closeTo(anchor.topInset + AppSpacing.md, 0.01),
    );
    // A 0.45 sheet on an 800px screen is 360px tall (the anchor is measured from
    // the bottom), so the chrome sits at 360 + 16.
    expect(anchor.topInset, closeTo(360, 1.5));
  });

  testWidgets('the chrome attaches while the category sheet is still loading', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        searchServiceProvider.overrideWithValue(_SlowSearch()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Cafes'));
    // The sheet switcher fades the home sheet out and the loading category
    // sheet in; the browse never completes.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      container.read(searchControllerProvider).status,
      SearchStatus.loading,
    );
    final SheetAnchor? anchor = container.read(sheetAnchorProvider);
    expect(anchor, isNotNull, reason: 'the chrome has nothing to attach to');
    expect(anchor!.topInset, closeTo(360, 1.5));
  });
}
