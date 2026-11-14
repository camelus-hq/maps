import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_spacing.dart';
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

/// Search screen: saved Home/Work and recent searches when empty, debounced
/// results while typing.
///
/// Selecting a result marks it as the selected place and returns to the map,
/// where the details sheet takes over. When a Home/Work slot is being filled
/// ([savedPlacePickProvider]) the selection is saved to that slot instead.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Always open on the recent list: drop any query/results left by an earlier
    // search so "Recent" (and Home/Work) is what the user sees first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(savedPlacePickProvider.notifier).clear();
            popOrHome(context);
          },
        ),
        title: TextField(
          controller: _text,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: switch (pick) {
              SavedPlaceSlot.home => 'Set home',
              SavedPlaceSlot.work => 'Set work',
              null => 'Search here',
            },
            border: InputBorder.none,
          ),
          onChanged: ref.read(searchControllerProvider.notifier).queryChanged,
          onSubmitted: _submit,
        ),
        actions: <Widget>[
          if (state.query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear',
              onPressed: () {
                _text.clear();
                ref.read(searchControllerProvider.notifier).reset();
              },
            ),
        ],
      ),
      body: _body(context, state, pick),
    );
  }

  Widget _body(BuildContext context, SearchState state, SavedPlaceSlot? pick) {
    switch (state.status) {
      case SearchStatus.loading:
        return const Center(child: CircularProgressIndicator());
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
          return const _Message(icon: Icons.search_off, text: 'No results');
        }
        return _resultsList(state.results, category);
    }
  }

  Widget _recentList() {
    final SavedPlaces saved = ref.watch(savedPlacesProvider);
    final List<RecentSearch> recents = ref.watch(recentSearchesProvider);
    return ListView(
      children: <Widget>[
        _SavedPlacesRow(
          saved: saved,
          onAdd: _beginPick,
          onOpen: (Place place) => unawaited(_openSaved(place)),
          onRemove: (SavedPlaceSlot slot) => unawaited(_clearSlot(slot)),
        ),
        const Divider(height: 1),
        _RecentHeader(
          onClear: recents.isEmpty
              ? null
              : () => unawaited(
                  ref.read(recentSearchesProvider.notifier).clear(),
                ),
        ),
        if (recents.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Text('No recent searches yet'),
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
      itemCount: results.length + leading,
      separatorBuilder: (BuildContext context, int index) =>
          const Divider(height: 1),
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
        return ListTile(
          leading: Icon(placeResultIcon(place.category)),
          title: Text(place.name),
          subtitle: Text(
            detail.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _select(place),
        );
      },
    );
  }

  /// The category suggestion shown at the top of the results when the query
  /// names a category chip ("cafes", "coffee"): a coloured magnifying glass and
  /// the chip name. Tapping browses that category nearby — the map stays
  /// visible with the places pinned and a results sheet.
  Widget _categoryTile(PlaceCategory category) {
    return ListTile(
      leading: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
      title: Text(category.label),
      onTap: () => _browseCategory(category),
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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _SavedPlaceCard(
              slot: SavedPlaceSlot.home,
              place: saved.home,
              icon: Icons.home,
              onAdd: onAdd,
              onOpen: onOpen,
              onRemove: onRemove,
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: _SavedPlaceCard(
              slot: SavedPlaceSlot.work,
              place: saved.work,
              icon: Icons.work,
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Place? value = place;
    final String subtitle = value == null
        ? 'Add'
        : (value.address ?? value.name);
    return InkWell(
      onTap: value == null ? () => onAdd(slot) : () => onOpen(value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 20,
              backgroundColor: scheme.primaryContainer,
              child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _label,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (value != null)
              PopupMenuButton<String>(
                tooltip: 'Remove $_label',
                icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                onSelected: (_) => onRemove(slot),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'remove',
                    child: Text('Remove $_label'),
                  ),
                ],
              )
            else
              const SizedBox(width: AppSpacing.sm),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Recent',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          FilledButton.tonal(
            onPressed: onClear,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              shape: const StadiumBorder(),
            ),
            child: const Text('Clear recents'),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
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
        Icons.history,
        text,
        null,
        null,
      ),
    };
    return ListTile(
      leading: Icon(icon),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => onOpen(entry),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.north_east),
              tooltip: place == null ? 'Search' : 'Directions',
              onPressed: () =>
                  place == null ? onOpen(entry) : onDirections(place),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
            onSelected: (_) => onRemove(entry),
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'remove',
                    child: Text('Remove from recent'),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 40, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(text, textAlign: TextAlign.center),
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}
