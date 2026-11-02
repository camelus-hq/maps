import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../domain/entities/lat_lon.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/entities/place_category.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/search.dart';
import '../../../state/settings.dart';
import '../../common/error_text.dart';
import '../../common/navigation.dart';
import '../../common/place_result_icon.dart';

/// Search screen: recent queries when empty, debounced results while typing.
///
/// Selecting a result marks it as the selected place and returns to the map,
/// where the details sheet takes over.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Submits the query. A query that names a browse category ("cafes",
  /// "coffee") browses it near the map view and returns to the map, where the
  /// results sheet shows the places pinned — a normal text search stays on this
  /// screen.
  void _submit(String value) {
    if (placeCategoryForSearch(value) != null) {
      unawaited(ref.read(searchControllerProvider.notifier).submit(value));
      popOrHome(context);
      return;
    }
    unawaited(ref.read(searchControllerProvider.notifier).submit(value));
  }

  /// Selecting a result focuses the map on it (via the same `place.select`
  /// command agents use) and returns to the map, where the details sheet opens.
  Future<void> _select(Place place) async {
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => popOrHome(context),
        ),
        title: TextField(
          controller: _text,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search here',
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
      body: _body(context, state),
    );
  }

  Widget _body(BuildContext context, SearchState state) {
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
        return _recentList(state.recentQueries);
      case SearchStatus.data:
        final PlaceCategory? category = placeCategoryForSearch(state.query);
        if (state.results.isEmpty && category == null) {
          return const _Message(icon: Icons.search_off, text: 'No results');
        }
        return _resultsList(state.results, category);
    }
  }

  Widget _recentList(List<String> recent) {
    if (recent.isEmpty) {
      return const _Message(icon: Icons.search, text: 'Search for a place');
    }
    return ListView(
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Text('Recent'),
        ),
        for (final String query in recent)
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(query),
            onTap: () {
              _text.text = query;
              _submit(query);
            },
          ),
      ],
    );
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
      popOrHome(context);
    }
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
