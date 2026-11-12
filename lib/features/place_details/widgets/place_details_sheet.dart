import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/opening_hours.dart';
import '../../../core/utils/osm_payments.dart';
import '../../../domain/entities/lat_lon.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/entities/review_place.dart';
import '../../../domain/entities/review_summary.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/place.dart';
import '../../../state/reviews.dart';
import '../../../state/route.dart';
import '../../../state/search.dart';
import '../../../state/settings.dart';
import '../../../state/usecases.dart';
import '../../common/map_sheet.dart';
import '../../reviews/widgets/place_reviews_section.dart';
import '../../reviews/widgets/star_rating.dart';
import 'place_hours_line.dart';
import 'place_osm_tags.dart';
import 'place_payments.dart';
import 'place_photos.dart';
import 'place_weekly_hours.dart';

/// The three panes of the place sheet, like the reference app: the summary
/// facts, the reviews, and our own photos.
enum _PlaceTab { overview, reviews, photos }

/// Draggable bottom sheet for the selected place.
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

class _PlaceDetailsSheetState extends ConsumerState<PlaceDetailsSheet>
    with SingleTickerProviderStateMixin {
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

  /// Drives the real Material [TabBar] (animated indicator) and the animated
  /// body switch below it.
  late final TabController _tabs = TabController(
    length: _PlaceTab.values.length,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted && !_tabs.indexIsChanging) {
      // Rebuild once the indicator has settled on the new tab.
      setState(() {});
    }
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
        ((AppSpacing.sm + box.size.height + AppSpacing.md) / viewport).clamp(
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    // The OSM lookup fills in phone/e-mail/website, wheelchair access and the
    // opening hours. It starts when the sheet opens and the sheet re-renders
    // when it lands; until then it simply shows less.
    final AsyncValue<Place?> osm = ref.watch(
      osmPlaceDetailsProvider(widget.place.id),
    );
    final Place place = widget.place.withOsmDetails(osm.value);
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

    return MapSheet(
      initialChildSize: _half,
      minChildSize: peek,
      maxChildSize: _full,
      snap: true,
      snapSizes: <double>[peek, _half, _full],
      builder: (BuildContext context, ScrollController scrollController) {
        return Material(
          color: scheme.surface,
          elevation: 12,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.sheetRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            children: <Widget>[
              // The summary is the same at every sheet size; the peek is sized
              // to show exactly this much and the tabs sit below the fold.
              Column(
                key: _summaryKey,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _Handle(color: scheme.outlineVariant),
                  const SizedBox(height: AppSpacing.sm),
                  _header(context, place),
                  const SizedBox(height: AppSpacing.sm),
                  _ratingRow(context, summary, loading: reviewsLoading),
                  // A place that takes Bitcoin Lightning / Chaumian ecash
                  // advertises it right below the review (the rest of its
                  // payments live in the Overview).
                  if (place.promotedPayments.isNotEmpty)
                    OsmCryptoBadges(methods: place.promotedPayments),
                  const SizedBox(height: AppSpacing.xs),
                  _subtitle(context, place),
                  PlaceHoursLine(hours: place.openingHours),
                  const SizedBox(height: AppSpacing.md),
                  _actions(context, place),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _tabBar(context),
              _tabBody(context, place, summary),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, Place place) {
    final ThemeData theme = Theme.of(context);
    final bool bookmarked = _isBookmarked();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              place.name,
              style: theme.textTheme.headlineSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _CircleButton(
          icon: bookmarked ? Icons.bookmark : Icons.bookmark_border,
          tooltip: bookmarked ? 'Saved' : 'Save',
          onTap: () => unawaited(_toggleSave(bookmarked)),
        ),
        const SizedBox(width: AppSpacing.xs),
        _CircleButton(
          icon: Icons.share_outlined,
          tooltip: 'Share',
          onTap: () => unawaited(_share()),
        ),
        const SizedBox(width: AppSpacing.xs),
        _CircleButton(
          icon: Icons.close,
          tooltip: 'Close',
          onTap: () => ref.read(selectedPlaceProvider.notifier).clear(),
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    if (summary.isEmpty) {
      if (loading) {
        // Avoid flashing "Write a review" while the reviews are still loading.
        return const SizedBox(height: 40);
      }
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _openComposer,
          icon: const Icon(Icons.rate_review_outlined, size: 18),
          label: const Text('Write a review'),
        ),
      );
    }
    return InkWell(
      onTap: () => _tabs.animateTo(_PlaceTab.reviews.index),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            Text(
              summary.stars.toStringAsFixed(1),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StarRating(value: summary.stars, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '(${summary.reviewCount})',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "170 m · Cafe", the distance and category line.
  Widget _subtitle(BuildContext context, Place place) {
    final ThemeData theme = Theme.of(context);
    final LatLon? from = ref.watch(userLocationProvider).value;
    final bool imperial = ref.watch(imperialUnitsProvider);
    final List<String> parts = <String>[
      if (from != null)
        formatDistance(place.position.distanceTo(from), imperial: imperial),
      if (place.category != null && place.category!.trim().isNotEmpty)
        place.category!.trim(),
    ];
    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      parts.join(' · '),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// The primary action pills: Directions, Call, Website.
  Widget _actions(BuildContext context, Place place) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _ActionPill(
            icon: Icons.directions,
            label: 'Directions',
            primary: true,
            onTap: () => unawaited(
              ref.read(routeControllerProvider.notifier).plan(place),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _ActionPill(
            icon: Icons.call,
            label: 'Call',
            enabled: place.hasPhone,
            onTap: () => unawaited(_call()),
          ),
          const SizedBox(width: AppSpacing.sm),
          _ActionPill(
            icon: Icons.language,
            label: 'Website',
            enabled: place.website?.trim().isNotEmpty ?? false,
            onTap: () => unawaited(_openWebsite()),
          ),
        ],
      ),
    );
  }

  /// The real Material tab bar (animated indicator) for the three panes.
  Widget _tabBar(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return TabBar(
      controller: _tabs,
      indicatorColor: scheme.primary,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      dividerColor: scheme.outlineVariant,
      tabs: const <Widget>[
        Tab(text: 'Overview'),
        Tab(text: 'Reviews'),
        Tab(text: 'Photos'),
      ],
    );
  }

  Widget _tabBody(BuildContext context, Place place, ReviewSummary summary) {
    final Widget body = switch (_PlaceTab.values[_tabs.index]) {
      _PlaceTab.overview => _overview(context, place),
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
      child: KeyedSubtree(
        key: ValueKey<_PlaceTab>(_PlaceTab.values[_tabs.index]),
        child: body,
      ),
    );
  }

  /// The Overview facts, each row only when we actually know the value.
  Widget _overview(BuildContext context, Place place) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> rows = <Widget>[];
    final String? address = place.address;
    if (address != null && address.trim().isNotEmpty) {
      rows.add(
        _InfoRow(
          icon: Icons.place_outlined,
          text: address.trim(),
          trailing: IconButton(
            icon: const Icon(Icons.copy_all_outlined, size: 20),
            tooltip: 'Copy address',
            onPressed: () => unawaited(_copyAddress()),
          ),
        ),
      );
    }
    // The general weekly hours (all days), after the address.
    if (place.openingHours != null &&
        weeklyOpeningHours(place.openingHours, DateTime.now()) != null) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: PlaceWeeklyHours(hours: place.openingHours),
        ),
      );
    }
    final String? phone = place.phone;
    if (phone != null && phone.trim().isNotEmpty) {
      rows.add(
        _InfoRow(
          icon: Icons.call_outlined,
          text: phone.trim(),
          onTap: () => unawaited(_call()),
        ),
      );
    }
    final String? website = place.website;
    if (website != null && website.trim().isNotEmpty) {
      rows.add(
        _InfoRow(
          icon: Icons.language,
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
          icon: Icons.mail_outline,
          text: email.trim(),
          link: true,
          onTap: () => unawaited(_email()),
        ),
      );
    }
    if (place.wheelchairAccessible == true) {
      rows.add(
        const _InfoRow(icon: Icons.accessible, text: 'Wheelchair accessible'),
      );
    }
    final String? wheelchairDescription = place.wheelchairDescription;
    if (wheelchairDescription != null) {
      rows.add(
        _InfoRow(icon: Icons.accessible_forward, text: wheelchairDescription),
      );
    }
    final String? takeaway = place.takeaway;
    if (takeaway != null) {
      rows.add(
        _InfoRow(icon: Icons.takeout_dining, text: _takeawayLabel(takeaway)),
      );
    }
    final List<OsmPaymentMethod> payments = place.paymentMethods;
    if (payments.isNotEmpty) {
      rows.add(OsmPaymentMethods(methods: payments));
    }
    final String? paymentDescription = place.paymentDescription;
    if (paymentDescription != null) {
      rows.add(_InfoRow(icon: Icons.notes_outlined, text: paymentDescription));
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
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ...rows,
        if (hasFacts) const SizedBox(height: AppSpacing.xs),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(bookmarked ? 'Removed' : 'Saved')));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Address copied')));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(unavailable)));
    }
  }

  Future<void> _share() async {
    await ref.read(commandRegistryProvider).dispatch(
      'place.share',
      <String, Object?>{'id': widget.place.id},
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Share text copied')));
    }
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// A round, tonal icon button — the Save / Share / Close row in the header.
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// A primary (filled) or tonal action pill.
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color background = primary
        ? scheme.primary
        : scheme.surfaceContainerHighest;
    final Color foreground = !enabled
        ? scheme.outline
        : primary
        ? scheme.onPrimary
        : scheme.onSurfaceVariant;
    return Material(
      color: background,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: link ? scheme.primary : null,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}

/// A readable label for OSM's `takeaway` tag.
String _takeawayLabel(String value) => switch (value.trim().toLowerCase()) {
  'yes' || 'true' || '1' => 'Takeaway available',
  'only' => 'Takeaway only',
  'no' || 'false' || '0' => 'No takeaway',
  final String other => 'Takeaway: $other',
};
