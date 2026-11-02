import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../domain/entities/lat_lon.dart';
import '../../../domain/entities/place.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/home.dart';
import '../../../state/search.dart';
import '../../../state/settings.dart';
import '../../common/error_text.dart';
import '../../common/place_result_icon.dart';

/// The draggable results sheet shown while browsing a category: the map stays
/// visible behind it with the nearby places highlighted.
class CategoryResultsSheet extends ConsumerWidget {
  const CategoryResultsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String? category = ref.watch(selectedCategoryProvider);
    final SearchState search = ref.watch(searchControllerProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const <double>[0.45, 0.9],
      builder: (BuildContext context, ScrollController scrollController) {
        return Material(
          color: scheme.surface,
          elevation: 12,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.sheetRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  0,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        category ?? 'Nearby',
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: () => unawaited(
                        ref
                            .read(commandRegistryProvider)
                            .dispatch(
                              'search.category',
                              const <String, Object?>{},
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _body(context, ref, search, scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    SearchState search,
    ScrollController scrollController,
  ) {
    switch (search.status) {
      case SearchStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case SearchStatus.error:
        final ({IconData icon, String text}) presentation = errorPresentation(
          search.error,
          fallback: 'Could not load places',
        );
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  presentation.icon,
                  size: 32,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(presentation.text, textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      case SearchStatus.idle:
        return const SizedBox.shrink();
      case SearchStatus.data:
        if (search.results.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('No places found nearby'),
            ),
          );
        }
        return _results(context, ref, search.results, scrollController);
    }
  }

  Widget _results(
    BuildContext context,
    WidgetRef ref,
    List<Place> places,
    ScrollController scrollController,
  ) {
    final LatLon? from = ref.watch(userLocationProvider).value;
    final bool imperial = ref.watch(imperialUnitsProvider);
    return ListView.separated(
      controller: scrollController,
      itemCount: places.length,
      separatorBuilder: (BuildContext context, int index) =>
          const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final Place place = places[index];
        final List<String> detail = <String>[?place.category, ?place.address];
        if (from != null) {
          detail.add(
            formatDistance(place.position.distanceTo(from), imperial: imperial),
          );
        }
        return ListTile(
          leading: Icon(placeResultIcon(place.category)),
          title: Text(place.name),
          subtitle: detail.isEmpty
              ? null
              : Text(
                  detail.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => unawaited(
            ref.read(commandRegistryProvider).dispatch(
              'place.select',
              <String, Object?>{'id': place.id},
            ),
          ),
        );
      },
    );
  }
}
