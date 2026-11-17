import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import '../../../domain/entities/lat_lon.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/entities/place_category.dart';
import '../../../domain/entities/recent_search.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/saved_places.dart';
import '../../../state/search.dart';
import '../../../state/settings.dart';
import '../../common/error_text.dart';
import '../../common/navigation.dart';
import '../../common/place_result_icon.dart';
import '../../design/play.dart';

/// Search screen: saved Home/Work and recent searches when empty, debounced
/// results while typing — all in the play style.
///
/// Selecting a result marks it as the selected place and returns to the map,
/// where the details sheet takes over. When a Home/Work slot is being filled
/// ([savedPlacePickProvider]) the selection is saved to that slot instead.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.initialQuery, super.key});

  /// A query carried in the URL (`/search?q=…`), seeded into the field and run
  /// once on open so a deep link lands on its results. `null` on a plain open.
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    final String? initial = widget.initialQuery;
    if (initial != null) {
      _text.text = initial;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (initial != null) {
        unawaited(
          ref.read(searchControllerProvider.notifier).submitText(initial),
        );
      } else {
        // Always open on the recent list: drop any query/results left by an
        // earlier search so "Recent" (and Home/Work) is what the user sees
        // first.
        ref.read(searchControllerProvider.notifier).reset();
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Submits the query. A query that names a browse category ("cafes",
  /// "coffee") browses it near the map view and returns to the map, where the
  /// results sheet shows the places pinned — a normal text search stays on this
  /// screen. While picking a Home/Work slot a plain search runs instead.
  void _submit(String value) {
    if (ref.read(savedPlacePickProvider) == null &&
        placeCategoryForSearch(value) != null) {
      unawaited(ref.read(searchControllerProvider.notifier).submit(value));
      // Replace the search list with the results route so back lands on the map.
      openCategory(context, replace: true);
      return;
    }
    unawaited(ref.read(searchControllerProvider.notifier).submitText(value));
  }

  /// Selecting a result focuses the map on it (via the same `place.select`
  /// command agents use) and returns to the map, where the details sheet opens.
  /// When a Home/Work slot is being filled, the place is saved there instead.
  Future<void> _select(Place place) async {
    final SavedPlaceSlot? slot = ref.read(savedPlacePickProvider);
    if (slot != null) {
      ref.read(savedPlacePickProvider.notifier).clear();
      await ref.read(commandRegistryProvider).dispatch(
        slot == SavedPlaceSlot.home ? 'place.setHome' : 'place.setWork',
        <String, Object?>{'id': place.id},
      );
      if (mounted) {
        popOrHome(context);
      }
      return;
    }
    await ref.read(commandRegistryProvider).dispatch(
      'place.select',
      <String, Object?>{'id': place.id},
    );
    if (mounted) {
      popOrHome(context);
    }
  }

  /// Starts directions to [place] (the row's ↗ button) and returns to the map.
  Future<void> _directions(Place place) async {
    await ref.read(commandRegistryProvider).dispatch(
      'place.select',
      <String, Object?>{'id': place.id, 'focus': false},
    );
    await ref.read(commandRegistryProvider).dispatch(
      'route.plan',
      <String, Object?>{'id': place.id},
    );
    if (mounted) {
      popOrHome(context);
    }
  }

  /// Starts filling a Home/Work slot: the screen switches to pick mode.
  void _beginPick(SavedPlaceSlot slot) {
    ref.read(savedPlacePickProvider.notifier).begin(slot);
    _text.clear();
    ref.read(searchControllerProvider.notifier).reset();
  }

  /// Removes a saved Home/Work place.
  Future<void> _clearSlot(SavedPlaceSlot slot) async {
    await ref
        .read(commandRegistryProvider)
        .dispatch(
          slot == SavedPlaceSlot.home ? 'place.clearHome' : 'place.clearWork',
          const <String, Object?>{},
        );
  }

  /// Opens a saved Home/Work place (its details sheet) on the map.
  Future<void> _openSaved(Place place) async {
    await ref.read(commandRegistryProvider).dispatch(
      'place.select',
      <String, Object?>{'id': place.id},
    );
    if (mounted) {
      popOrHome(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SearchState state = ref.watch(searchControllerProvider);
    final SavedPlaceSlot? pick = ref.watch(savedPlacePickProvider);
    final String hint = switch (pick) {
      SavedPlaceSlot.home => 'Set home',
      SavedPlaceSlot.work => 'Set work',
      null => 'Search here',
    };
    return PlayScaffold(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PlaySpace.sm,
              PlaySpace.sm,
              PlaySpace.lg,
              PlaySpace.sm,
            ),
            child: Row(
              children: <Widget>[
                PlayIconButton(
                  icon: PlayIcons.back,
                  variant: PlayIconButtonVariant.plain,
                  size: 44,
                  semanticLabel: 'Back',
                  onPressed: () {
                    ref.read(savedPlacePickProvider.notifier).clear();
                    popOrHome(context);
                  },
                ),
                const SizedBox(width: PlaySpace.xs),
                Expanded(
                  child: PlayTextField(
                    controller: _text,
                    hint: hint,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    leading: Icon(
                      PlayIcons.search,
                      size: 20,
                      color: PlayColors.of(context).inkMuted,
                    ),
                    onChanged: ref
                        .read(searchControllerProvider.notifier)
                        .queryChanged,
                    onSubmitted: _submit,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _body(context, state, pick)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, SearchState state, SavedPlaceSlot? pick) {
    switch (state.status) {
      case SearchStatus.loading:
        return const Center(child: PlaySpinner());
      case SearchStatus.error:
        final ({IconData icon, String text}) presentation = errorPresentation(
          state.error,
          fallback: 'Search is unavailable right now.',
        );
        return _Message(
          icon: presentation.icon,
          text: presentation.text,
          onRetry: state.query.isEmpty ? null : () => _submit(state.query),
        );
      case SearchStatus.idle:
        return _recentList();
      case SearchStatus.data:
        final PlaceCategory? category = pick == null
            ? placeCategoryForSearch(state.query)
            : null;
        if (state.results.isEmpty && category == null) {
          return const _Message(
            icon: PlayIcons.unsupported,
            text: 'No results',
          );
        }
        return _resultsList(state.results, category);
    }
  }

  Widget _recentList() {
    final SavedPlaces saved = ref.watch(savedPlacesProvider);
    final List<RecentSearch> recents = ref.watch(recentSearchesProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        PlaySpace.md,
        0,
        PlaySpace.md,
        PlaySpace.xxl,
      ),
      children: <Widget>[
        _SavedPlacesRow(
          saved: saved,
          onAdd: _beginPick,
          onOpen: (Place place) => unawaited(_openSaved(place)),
          onRemove: (SavedPlaceSlot slot) => unawaited(_clearSlot(slot)),
        ),
        const PlayDivider(),
        _RecentHeader(
          onClear: recents.isEmpty
              ? null
              : () => unawaited(
                  ref.read(recentSearchesProvider.notifier).clear(),
                ),
        ),
        if (recents.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PlaySpace.lg,
              PlaySpace.sm,
              PlaySpace.lg,
              PlaySpace.xl,
            ),
            child: Text(
              'No recent searches yet',
              style: PlayType.body.copyWith(
                color: PlayColors.of(context).inkMuted,
              ),
            ),
          )
        else
          for (final RecentSearch entry in recents)
            _RecentTile(
              entry: entry,
              onOpen: _openRecent,
              onDirections: _directions,
              onRemove: (RecentSearch removed) => unawaited(
                ref.read(recentSearchesProvider.notifier).remove(removed),
              ),
            ),
      ],
    );
  }

  void _openRecent(RecentSearch entry) {
    switch (entry) {
      case RecentPlaceSearch(:final Place place):
        unawaited(_select(place));
      case RecentTextSearch(:final String text):
        _text.text = text;
        _submit(text);
    }
  }

  Widget _resultsList(List<Place> results, PlaceCategory? category) {
    final LatLon? from = ref.watch(userLocationProvider).value;
    final bool imperial = ref.watch(imperialUnitsProvider);
    final int leading = category == null ? 0 : 1;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: PlaySpace.lg),
      itemCount: results.length + leading,
      separatorBuilder: (BuildContext context, int index) =>
          const PlayDivider(),
      itemBuilder: (BuildContext context, int index) {
        if (category != null && index == 0) {
          return _categoryTile(category);
        }
        final Place place = results[index - leading];
        final String? placeCategory = place.category;
        final String? address = place.address;
        final List<String> detail = <String>[?placeCategory, ?address];
        if (from != null) {
          detail.add(
            formatDistance(place.position.distanceTo(from), imperial: imperial),
          );
        }
        return PlayRow(
          icon: placeResultIcon(place.category),
          label: place.name,
          subtitle: detail.isEmpty ? null : detail.join(' · '),
          onTap: () => unawaited(_select(place)),
        );
      },
    );
  }

  /// The category suggestion shown at the top of the results when the query
  /// names a category chip ("cafes", "coffee"): a coloured magnifying glass and
  /// the chip name. Tapping browses that category nearby — the map stays
  /// visible with the places pinned and a results sheet.
  Widget _categoryTile(PlaceCategory category) {
    return PlayRow(
      icon: PlayIcons.search,
      label: category.label,
      onTap: () => unawaited(_browseCategory(category)),
    );
  }

  Future<void> _browseCategory(PlaceCategory category) async {
    await ref.read(commandRegistryProvider).dispatch(
      'search.category',
      <String, Object?>{'name': category.id},
    );
    if (mounted) {
      openCategory(context, replace: true);
    }
  }
}

/// The Home / Work saved row at the top of the empty search list.
class _SavedPlacesRow extends StatelessWidget {
  const _SavedPlacesRow({
    required this.saved,
    required this.onAdd,
    required this.onOpen,
    required this.onRemove,
  });

  final SavedPlaces saved;
  final ValueChanged<SavedPlaceSlot> onAdd;
  final ValueChanged<Place> onOpen;
  final ValueChanged<SavedPlaceSlot> onRemove;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _SavedPlaceCard(
              slot: SavedPlaceSlot.home,
              place: saved.home,
              icon: PlayIcons.home,
              onAdd: onAdd,
              onOpen: onOpen,
              onRemove: onRemove,
            ),
          ),
          ColoredBox(color: colors.line, child: const SizedBox(width: 1)),
          Expanded(
            child: _SavedPlaceCard(
              slot: SavedPlaceSlot.work,
              place: saved.work,
              icon: PlayIcons.work,
              onAdd: onAdd,
              onOpen: onOpen,
              onRemove: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}

/// One half of the saved row: a circular icon, the slot label and either an
/// address or "Add", with a menu to remove a set place.
class _SavedPlaceCard extends StatelessWidget {
  const _SavedPlaceCard({
    required this.slot,
    required this.place,
    required this.icon,
    required this.onAdd,
    required this.onOpen,
    required this.onRemove,
  });

  final SavedPlaceSlot slot;
  final Place? place;
  final IconData icon;
  final ValueChanged<SavedPlaceSlot> onAdd;
  final ValueChanged<Place> onOpen;
  final ValueChanged<SavedPlaceSlot> onRemove;

  String get _label => switch (slot) {
    SavedPlaceSlot.home => 'Home',
    SavedPlaceSlot.work => 'Work',
  };

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final Place? value = place;
    final String subtitle = value == null
        ? 'Add'
        : (value.address ?? value.name);
    return PlayPressable(
      onTap: value == null ? () => onAdd(slot) : () => onOpen(value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PlaySpace.xs,
          PlaySpace.md,
          PlaySpace.xs,
          PlaySpace.md,
        ),
        child: Row(
          children: <Widget>[
            PlaySurface(
              radius: PlayRadii.pill,
              tone: PlayTone.soft,
              shadow: PlayShadow.none,
              padding: const EdgeInsets.all(PlaySpace.md),
              child: Icon(icon, size: 20, color: colors.onPrimarySoft),
            ),
            const SizedBox(width: PlaySpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _label,
                    style: PlayType.subtitle.copyWith(color: colors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PlayType.caption.copyWith(color: colors.inkMuted),
                  ),
                ],
              ),
            ),
            if (value != null)
              PlayMenuButton<String>(
                semanticLabel: 'Remove $_label',
                onSelected: (String _) => onRemove(slot),
                items: <PlayMenuItem<String>>[
                  PlayMenuItem<String>(
                    value: 'remove',
                    label: 'Remove $_label',
                  ),
                ],
              )
            else
              const SizedBox(width: PlaySpace.sm),
          ],
        ),
      ),
    );
  }
}

/// The "Recent" header with its "Clear recents" pill.
class _RecentHeader extends StatelessWidget {
  const _RecentHeader({required this.onClear});

  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final VoidCallback? clear = onClear;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PlaySpace.xs,
        PlaySpace.sm,
        PlaySpace.xs,
        PlaySpace.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Recent',
              style: PlayType.subtitle.copyWith(color: colors.ink),
            ),
          ),
          PlayButton(
            label: 'Clear recents',
            variant: PlayButtonVariant.soft,
            size: PlayButtonSize.sm,
            onPressed: clear,
          ),
        ],
      ),
    );
  }
}

/// One recent row: a place (category glyph, name + address) or a text query
/// (clock, the query).
class _RecentTile extends StatelessWidget {
  const _RecentTile({
    required this.entry,
    required this.onOpen,
    required this.onDirections,
    required this.onRemove,
  });

  final RecentSearch entry;
  final ValueChanged<RecentSearch> onOpen;
  final ValueChanged<Place> onDirections;
  final ValueChanged<RecentSearch> onRemove;

  @override
  Widget build(BuildContext context) {
    final (
      IconData icon,
      String title,
      String? subtitle,
      Place? place,
    ) = switch (entry) {
      RecentPlaceSearch(place: final Place value) => (
        placeResultIcon(value.category),
        value.name,
        value.address ?? value.category,
        value,
      ),
      RecentTextSearch(text: final String text) => (
        PlayIcons.recent,
        text,
        null,
        null,
      ),
    };
    final Place? target = place;
    return PlayRow(
      icon: icon,
      label: title,
      subtitle: subtitle,
      onTap: () => onOpen(entry),
      showChevron: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PlayIconButton(
            icon: PlayIcons.goTo,
            variant: PlayIconButtonVariant.plain,
            size: 40,
            iconSize: 18,
            semanticLabel: target == null ? 'Search' : 'Directions',
            onPressed: () =>
                target == null ? onOpen(entry) : onDirections(target),
          ),
          PlayMenuButton<String>(
            semanticLabel: 'More',
            onSelected: (String _) => onRemove(entry),
            items: const <PlayMenuItem<String>>[
              PlayMenuItem<String>(
                value: 'remove',
                label: 'Remove from recent',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final VoidCallback? retry = onRetry;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 44, color: colors.inkFaint),
          const SizedBox(height: PlaySpace.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PlaySpace.xl),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: PlayType.body.copyWith(color: colors.inkMuted),
            ),
          ),
          if (retry != null) ...<Widget>[
            const SizedBox(height: PlaySpace.lg),
            PlayButton(
              label: 'Retry',
              icon: PlayIcons.refresh,
              variant: PlayButtonVariant.ghost,
              onPressed: retry,
            ),
          ],
        ],
      ),
    );
  }
}
