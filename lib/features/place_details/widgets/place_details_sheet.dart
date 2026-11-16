import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import '../../../core/utils/opening_hours.dart';
import '../../../core/utils/osm_payments.dart';
import '../../../domain/entities/lat_lon.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/entities/review_place.dart';
import '../../../domain/entities/review_summary.dart';
import '../../../domain/entities/transit.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/place.dart';
import '../../../state/reviews.dart';
import '../../../state/route.dart';
import '../../../state/search.dart';
import '../../../state/settings.dart';
import '../../../state/transit_stop_board.dart';
import '../../../state/usecases.dart';
import '../../common/map_sheet.dart';
import '../../common/shimmer.dart';
import '../../design/play.dart';
import '../../reviews/widgets/place_reviews_section.dart';
import '../../reviews/widgets/star_rating.dart';
import 'place_departures_tab.dart';
import 'place_hours_line.dart';
import 'place_osm_tags.dart';
import 'place_payments.dart';
import 'place_photos.dart';
import 'place_weekly_hours.dart';

/// The panes of the place sheet. **Departures** is only shown for a
/// public-transport stop/station and always comes first (before Overview), like
/// the reference app.
enum _PlaceTab { departures, overview, reviews, photos }

/// The panes shown for a non-transit place.
const List<_PlaceTab> _baseTabs = <_PlaceTab>[
  _PlaceTab.overview,
  _PlaceTab.reviews,
  _PlaceTab.photos,
];

/// Every pane, in order, for a transit stop.
const List<_PlaceTab> _transitTabs = <_PlaceTab>[
  _PlaceTab.departures,
  _PlaceTab.overview,
  _PlaceTab.reviews,
  _PlaceTab.photos,
];

/// Draggable bottom sheet for the selected place, in the play style.
///
/// The place summary — the name, the rating / review entry, the promoted-payment
/// badges, the distance/hours line and the primary actions — is the same at
/// every size; the **peek** is simply tall enough to show it and folds just
/// below the actions, while dragging up adds the Overview / Reviews / Photos
/// tabs. Contact and accessibility facts come from OpenStreetMap (`contact:*`,
/// `wheelchair`) and are looked up once per place, never blocking the sheet.
class PlaceDetailsSheet extends ConsumerStatefulWidget {
  const PlaceDetailsSheet({super.key, required this.place});

  final Place place;

  @override
  ConsumerState<PlaceDetailsSheet> createState() => _PlaceDetailsSheetState();
}

class _PlaceDetailsSheetState extends ConsumerState<PlaceDetailsSheet> {
  /// The default half height and the full height.
  static const double _half = 0.5;
  static const double _full = 0.9;

  /// The peek fraction used until the summary has been measured for this place.
  static const double _peekFallback = 0.32;

  /// Measures the summary so the peek can be exactly tall enough for it — the
  /// summary height varies with the place (badges, a rating or a review entry,
  /// an address line), so a fixed fraction would either clip the actions or
  /// leave the tabs poking above the fold.
  final GlobalKey _summaryKey = GlobalKey();

  /// The measured peek, as a fraction of the sheet viewport.
  double? _peekFraction;

  /// The panes currently shown (3, or 4 with Departures for a transit stop).
  List<_PlaceTab> _visibleTabs = _baseTabs;

  /// The selected pane index into [_visibleTabs].
  int _selected = 0;

  /// Whether [_visibleTabs] currently includes the Departures pane.
  bool _showingTransitTabs = false;

  /// Whether the stop board has been opened for this place (so the async OSM
  /// lookup flipping the place to "transit" opens it exactly once).
  bool _boardRequested = false;

  /// The board notifier, captured so [dispose] can close the board without
  /// touching `ref` (which is unsafe once the widget is deactivated).
  late final TransitStopBoardController _board;

  @override
  void initState() {
    super.initState();
    _board = ref.read(transitStopBoardProvider.notifier);
    // A station opens on its Departures tab; the OSM lookup may flip a place to
    // "transit" later and `_syncTransitTabs` re-selects it then.
    final bool transit = isTransitStopPlace(widget.place);
    _showingTransitTabs = transit;
    _visibleTabs = transit ? _transitTabs : _baseTabs;
    _selected = transit ? _tabIndex(_PlaceTab.departures) : 0;
  }

  @override
  void dispose() {
    // Closing the sheet clears the stop board and the lines it drew — but not
    // when another place sheet (with a different place) has already replaced it
    // under the sheet switcher and opened its own board.
    _board.closeFor(widget.place.id);
    super.dispose();
  }

  /// The sheet index of [tab] within the currently visible panes.
  int _tabIndex(_PlaceTab tab) {
    final int index = _visibleTabs.indexOf(tab);
    return index < 0 ? 0 : index;
  }

  /// Switches the pane set when the place turns out to be a transit stop (the
  /// OSM element lookup can land after the sheet opens). Done after the frame so
  /// we never mutate state during build.
  void _syncTransitTabs(bool transit) {
    if (transit == _showingTransitTabs) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || transit == _showingTransitTabs) {
        return;
      }
      setState(() {
        final _PlaceTab current =
            _visibleTabs[_selected.clamp(0, _visibleTabs.length - 1)];
        _visibleTabs = transit ? _transitTabs : _baseTabs;
        _showingTransitTabs = transit;
        // A station opens straight on its departures.
        _selected = transit
            ? _tabIndex(_PlaceTab.departures)
            : _tabIndex(current);
      });
    });
  }

  /// Opens the stop board (departures + map lines) once for a transit place.
  void _openBoardIfTransit(Place place) {
    if (_boardRequested || !isTransitStopPlace(place)) {
      return;
    }
    _boardRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _board.openFromPlace(place);
      }
    });
  }

  /// Re-measures the summary after layout and updates the peek if it changed.
  void _measurePeek(double viewport) {
    if (!mounted || viewport <= 0) {
      return;
    }
    final RenderObject? box = _summaryKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return;
    }
    // The ListView's top padding, the summary and the gap before the tabs.
    final double next =
        ((PlaySpace.sm + box.size.height + PlaySpace.md) / viewport).clamp(
          0.1,
          0.45,
        );
    final double? current = _peekFraction;
    if (current == null || (next - current).abs() > 0.004) {
      setState(() => _peekFraction = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The OSM lookup fills in phone/e-mail/website, wheelchair access and the
    // opening hours. It starts when the sheet opens and the sheet re-renders
    // when it lands; until then it simply shows less.
    final AsyncValue<Place?> osm = ref.watch(
      osmPlaceDetailsProvider(widget.place.id),
    );
    final Place place = widget.place.withOsmDetails(osm.value);
    // The Overview facts (address apart) come from the OSM element lookup, so
    // the pane shimmers until it lands instead of flashing "No more details".
    final bool osmLoading = osm.isLoading;
    final String placeKey = ReviewPlace.keyFor(place.id);
    final bool reviewsLoading = ref
        .watch(placeReviewsProvider(placeKey))
        .isLoading;
    final ReviewSummary summary = ref.watch(
      placeReviewSummaryProvider(placeKey),
    );

    final double viewport = MediaQuery.sizeOf(context).height;
    final double peek = (_peekFraction ?? _peekFallback).clamp(0.1, 0.45);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measurePeek(viewport));

    // A transit stop gets a Departures tab first and its lines drawn on the map;
    // both can switch on when the OSM lookup lands.
    final bool transit = isTransitStopPlace(place);
    _syncTransitTabs(transit);
    _openBoardIfTransit(place);

    return MapSheet(
      initialChildSize: _half,
      minChildSize: peek,
      maxChildSize: _full,
      snap: true,
      snapSizes: <double>[peek, _half, _full],
      builder: (BuildContext context, ScrollController scrollController) {
        return PlaySheet(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              PlaySpace.lg,
              PlaySpace.sm,
              PlaySpace.lg,
              PlaySpace.xl,
            ),
            children: <Widget>[
              // The summary is the same at every sheet size; the peek is sized
              // to show exactly this much and the tabs sit below the fold.
              Column(
                key: _summaryKey,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const PlaySheetHandle(),
                  const SizedBox(height: PlaySpace.xs),
                  _header(context, place),
                  const SizedBox(height: PlaySpace.sm),
                  _ratingRow(context, summary, loading: reviewsLoading),
                  // A place that takes Bitcoin Lightning / Chaumian ecash
                  // advertises it right below the review (the rest of its
                  // payments live in the Overview).
                  if (place.promotedPayments.isNotEmpty)
                    OsmCryptoBadges(methods: place.promotedPayments),
                  const SizedBox(height: PlaySpace.xs),
                  _subtitle(context, place),
                  // The lines serving a tapped transit stop, in their own
                  // colours, like the other transit screens.
                  if (transit) const PlaceStopLines(),
                  PlaceHoursLine(hours: place.openingHours),
                  const SizedBox(height: PlaySpace.lg),
                  _actions(context, place),
                ],
              ),
              const SizedBox(height: PlaySpace.lg),
              _tabBar(context),
              _tabBody(context, place, summary, overviewLoading: osmLoading),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, Place place) {
    final bool bookmarked = _isBookmarked();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: PlaySpace.xs),
            child: Text(
              place.name,
              style: PlayType.headline.copyWith(
                color: PlayColors.of(context).ink,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: PlaySpace.sm),
        PlayIconButton(
          icon: bookmarked ? PlayIcons.savedFilled : PlayIcons.saved,
          size: 40,
          semanticLabel: bookmarked ? 'Saved' : 'Save',
          onPressed: () => unawaited(_toggleSave(bookmarked)),
        ),
        const SizedBox(width: PlaySpace.xs),
        PlayIconButton(
          icon: PlayIcons.share,
          size: 40,
          semanticLabel: 'Share',
          onPressed: () => unawaited(_share()),
        ),
        const SizedBox(width: PlaySpace.xs),
        PlayIconButton(
          icon: PlayIcons.close,
          size: 40,
          semanticLabel: 'Close',
          onPressed: () => ref.read(selectedPlaceProvider.notifier).clear(),
        ),
      ],
    );
  }

  /// The rating line: stars and the review count, or — when nobody has reviewed
  /// the place — the "Write a review" entry point.
  Widget _ratingRow(
    BuildContext context,
    ReviewSummary summary, {
    required bool loading,
  }) {
    final PlayColors colors = PlayColors.of(context);
    if (summary.isEmpty) {
      if (loading) {
        // Avoid flashing "Write a review" while the reviews are still loading.
        return const SizedBox(height: 40);
      }
      return Align(
        alignment: Alignment.centerLeft,
        child: PlayButton(
          label: 'Write a review',
          icon: PlayIcons.review,
          variant: PlayButtonVariant.ghost,
          size: PlayButtonSize.sm,
          onPressed: _openComposer,
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: PlayPressable(
        onTap: () => setState(() => _selected = _tabIndex(_PlaceTab.reviews)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PlaySpace.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                summary.stars.toStringAsFixed(1),
                style: PlayType.subtitle.copyWith(color: colors.ink),
              ),
              const SizedBox(width: PlaySpace.sm),
              StarRating(value: summary.stars, size: 18),
              const SizedBox(width: PlaySpace.sm),
              Text(
                '(${summary.reviewCount})',
                style: PlayType.caption.copyWith(color: colors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "170 m · Cafe", the distance and category line.
  Widget _subtitle(BuildContext context, Place place) {
    final PlayColors colors = PlayColors.of(context);
    final LatLon? from = ref.watch(userLocationProvider).value;
    final bool imperial = ref.watch(imperialUnitsProvider);
    final String? category = place.category?.trim();
    final List<String> parts = <String>[
      if (from != null)
        formatDistance(place.position.distanceTo(from), imperial: imperial),
      if (category != null && category.isNotEmpty) category,
    ];
    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      parts.join(' · '),
      style: PlayType.body.copyWith(color: colors.inkMuted),
    );
  }

  /// The primary action pills: Directions, Call, Website.
  Widget _actions(BuildContext context, Place place) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          PlayButton(
            icon: PlayIcons.directions,
            label: 'Directions',
            size: PlayButtonSize.sm,
            onPressed: () => unawaited(
              ref
                  .read(routeControllerProvider.notifier)
                  .plan(place, suggestMode: true),
            ),
          ),
          const SizedBox(width: PlaySpace.sm),
          PlayButton(
            icon: PlayIcons.phone,
            label: 'Call',
            size: PlayButtonSize.sm,
            tone: PlayTone.neutral,
            onPressed: place.hasPhone ? () => unawaited(_call()) : null,
          ),
          const SizedBox(width: PlaySpace.sm),
          PlayButton(
            icon: PlayIcons.globe,
            label: 'Website',
            size: PlayButtonSize.sm,
            tone: PlayTone.neutral,
            onPressed: (place.website?.trim().isNotEmpty ?? false)
                ? () => unawaited(_openWebsite())
                : null,
          ),
        ],
      ),
    );
  }

  /// The play tab bar for the visible panes.
  Widget _tabBar(BuildContext context) {
    return PlayTabs(
      tabs: <String>[for (final _PlaceTab tab in _visibleTabs) _tabLabel(tab)],
      selectedIndex: _selected,
      onSelected: (int index) => setState(() => _selected = index),
    );
  }

  static String _tabLabel(_PlaceTab tab) => switch (tab) {
    _PlaceTab.departures => 'Departures',
    _PlaceTab.overview => 'Overview',
    _PlaceTab.reviews => 'Reviews',
    _PlaceTab.photos => 'Photos',
  };

  Widget _tabBody(
    BuildContext context,
    Place place,
    ReviewSummary summary, {
    required bool overviewLoading,
  }) {
    final _PlaceTab tab =
        _visibleTabs[_selected.clamp(0, _visibleTabs.length - 1)];
    final Widget body = switch (tab) {
      _PlaceTab.departures => const PlaceDeparturesTab(),
      _PlaceTab.overview => _overview(context, place, loading: overviewLoading),
      _PlaceTab.reviews => PlaceReviewsSection(
        place: place,
        showTitle: false,
        writeButtonWhenEmpty: false,
      ),
      _PlaceTab.photos => _photos(context, place),
    };
    // Animate the pane swap like a tab view, without giving up the sheet's
    // single drag-to-expand scroll view.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(key: ValueKey<_PlaceTab>(tab), child: body),
    );
  }

  /// The Overview facts, each row only when we actually know the value.
  Widget _overview(BuildContext context, Place place, {required bool loading}) {
    final PlayColors colors = PlayColors.of(context);
    final List<Widget> rows = <Widget>[];
    final String? address = place.address;
    if (address != null && address.trim().isNotEmpty) {
      rows.add(
        _InfoRow(
          icon: PlayIcons.place,
          text: address.trim(),
          trailing: PlayIconButton(
            icon: PlayIcons.copy,
            variant: PlayIconButtonVariant.plain,
            size: 36,
            iconSize: 18,
            semanticLabel: 'Copy address',
            onPressed: () => unawaited(_copyAddress()),
          ),
        ),
      );
    }
    // The address is ours already; the rest of the facts come from the OSM
    // lookup, so keep what we know and shimmer the rows still on their way
    // instead of flashing "No more details yet".
    if (loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ...rows,
          if (rows.isNotEmpty) const SizedBox(height: PlaySpace.xs),
          const _OverviewSkeleton(),
        ],
      );
    }
    // The general weekly hours (all days), after the address.
    if (place.openingHours != null &&
        weeklyOpeningHours(place.openingHours, DateTime.now()) != null) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: PlaySpace.sm),
          child: PlaceWeeklyHours(hours: place.openingHours),
        ),
      );
    }
    final String? phone = place.phone;
    if (phone != null && phone.trim().isNotEmpty) {
      rows.add(
        _InfoRow(
          icon: PlayIcons.phone,
          text: phone.trim(),
          onTap: () => unawaited(_call()),
        ),
      );
    }
    final String? website = place.website;
    if (website != null && website.trim().isNotEmpty) {
      rows.add(
        _InfoRow(
          icon: PlayIcons.globe,
          text: website.trim(),
          link: true,
          onTap: () => unawaited(_openWebsite()),
        ),
      );
    }
    final String? email = place.email;
    if (email != null && email.trim().isNotEmpty) {
      rows.add(
        _InfoRow(
          icon: PlayIcons.mail,
          text: email.trim(),
          link: true,
          onTap: () => unawaited(_email()),
        ),
      );
    }
    if (place.wheelchairAccessible == true) {
      rows.add(
        const _InfoRow(
          icon: PlayIcons.wheelchair,
          text: 'Wheelchair accessible',
        ),
      );
    } else if (place.wheelchairAccessible == false) {
      rows.add(
        const _InfoRow(
          icon: PlayIcons.wheelchairOff,
          text: 'Not wheelchair accessible',
        ),
      );
    }
    final String? wheelchairDescription = place.wheelchairDescription;
    if (wheelchairDescription != null) {
      rows.add(
        _InfoRow(icon: PlayIcons.wheelchair, text: wheelchairDescription),
      );
    }
    final String? takeaway = place.takeaway;
    if (takeaway != null) {
      rows.add(
        _InfoRow(icon: PlayIcons.takeaway, text: _takeawayLabel(takeaway)),
      );
    }
    final List<OsmPaymentMethod> payments = place.paymentMethods;
    final OsmPaymentMethods paymentSection = OsmPaymentMethods(
      methods: payments,
      tags: place.osmTags,
    );
    if (paymentSection.hasContent) {
      rows.add(paymentSection);
    }
    final String? paymentDescription = place.paymentDescription;
    if (paymentDescription != null) {
      rows.add(_InfoRow(icon: PlayIcons.note, text: paymentDescription));
    }
    // Developer option: every raw OSM tag, alphabetically.
    if (ref.watch(showOsmTagsProvider) && place.osmTags.isNotEmpty) {
      rows.add(PlaceOsmTags(tags: place.osmTags));
    }
    final bool hasFacts = rows.isNotEmpty;
    if (!hasFacts) {
      rows.add(
        Text(
          'No more details yet',
          style: PlayType.body.copyWith(color: colors.inkMuted),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ...rows,
        if (hasFacts) const SizedBox(height: PlaySpace.xs),
      ],
    );
  }

  /// The place's OpenStreetMap pictures, or an honest empty state (AGENTS.md
  /// §Assets: our own media corpus is empty).
  Widget _photos(BuildContext context, Place place) =>
      PlacePhotos(urls: place.imageUrls);

  bool _isBookmarked() =>
      ref
          .watch(bookmarksProvider)
          .value
          ?.any((Place saved) => saved.id == widget.place.id) ??
      false;

  Future<void> _toggleSave(bool bookmarked) async {
    final Place place = widget.place;
    await ref.read(toggleBookmarkProvider)(place, bookmarked: !bookmarked);
    await ref.read(savedMarkersProvider.notifier).refresh();
    if (!mounted) {
      return;
    }
    showPlayToast(context, bookmarked ? 'Removed' : 'Saved');
  }

  void _openComposer() => unawaited(
    ref.read(commandRegistryProvider).dispatch(
      'review.compose',
      <String, Object?>{'id': widget.place.id},
    ),
  );

  Future<void> _copyAddress() async {
    await ref.read(commandRegistryProvider).dispatch(
      'place.copyAddress',
      <String, Object?>{'id': widget.place.id},
    );
    if (mounted) {
      showPlayToast(context, 'Address copied');
    }
  }

  Future<void> _call() => _contact('place.call', 'No dialler available');

  Future<void> _email() => _contact('place.email', 'No e-mail app available');

  Future<void> _openWebsite() =>
      _contact('place.openWebsite', 'No browser available');

  /// Dispatches a contact command and reports when nothing opened (a missing
  /// app on the device, or an unusable OSM value).
  Future<void> _contact(String command, String unavailable) async {
    final Object? result = await ref.read(commandRegistryProvider).dispatch(
      command,
      <String, Object?>{'id': widget.place.id},
    );
    if (!mounted) {
      return;
    }
    final bool launched = result is Map && result['launched'] == true;
    if (!launched) {
      showPlayToast(context, unavailable);
    }
  }

  Future<void> _share() async {
    await ref.read(commandRegistryProvider).dispatch(
      'place.share',
      <String, Object?>{'id': widget.place.id},
    );
    if (mounted) {
      showPlayToast(context, 'Share text copied');
    }
  }
}

/// One Overview fact: an icon, the value, and an optional trailing action.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.trailing,
    this.onTap,
    this.link = false,
  });

  final IconData icon;
  final String text;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Draws the text in the accent colour (a tappable link).
  final bool link;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final Widget? trailingWidget = trailing;
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: PlaySpace.sm),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: colors.inkMuted),
          const SizedBox(width: PlaySpace.md),
          Expanded(
            child: Text(
              text,
              style: PlayType.body.copyWith(
                color: link ? colors.primary : colors.ink,
              ),
            ),
          ),
          ?trailingWidget,
        ],
      ),
    );
    final VoidCallback? tap = onTap;
    return tap == null ? content : PlayPressable(onTap: tap, child: content);
  }
}

/// The shimmering stand-in for the Overview facts while the OpenStreetMap
/// lookup is still in flight — icon-and-line rows matching [_InfoRow].
class _OverviewSkeleton extends StatelessWidget {
  const _OverviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final double width in const <double>[1.0, 0.75, 0.55, 0.85])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: PlaySpace.sm),
              child: Row(
                children: <Widget>[
                  const ShimmerBox(height: 20, circle: true),
                  const SizedBox(width: PlaySpace.md),
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: width,
                      child: const ShimmerBox(height: 16),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A readable label for OSM's `takeaway` tag.
String _takeawayLabel(String value) => switch (value.trim().toLowerCase()) {
  'yes' || 'true' || '1' => 'Takeaway available',
  'only' => 'Takeaway only',
  'no' || 'false' || '0' => 'No takeaway',
  final String other => 'Takeaway: $other',
};
