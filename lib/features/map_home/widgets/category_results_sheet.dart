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
import '../../common/map_sheet.dart';
import '../../common/navigation.dart';
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
    return MapSheet(
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
                      onPressed: () => unawaited(_close(ref, context)),
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

  /// Clears the browse and, when it is showing as a pushed route, pops it.
  Future<void> _close(WidgetRef ref, BuildContext context) async {
    await ref
        .read(commandRegistryProvider)
        .dispatch('search.category', const <String, Object?>{});
    if (context.mounted) {
      popOrHome(context);
    }
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    SearchState search,
    ScrollController scrollController,
  ) {
    switch (search.status) {
      case SearchStatus.loading:
        return _message(scrollController, const CircularProgressIndicator());
      case SearchStatus.error:
        final ({IconData icon, String text}) presentation = errorPresentation(
          search.error,
          fallback: 'Could not load places',
        );
        return _message(
          scrollController,
          Padding(
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
        return _message(scrollController, const SizedBox.shrink());
      case SearchStatus.data:
        if (search.results.isEmpty) {
          return _message(
            scrollController,
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('No places found nearby'),
            ),
          );
        }
        return _results(context, ref, search.results, scrollController);
    }
  }

  /// A centred [child] that still drives [scrollController].
  ///
  /// [MapSheet] can only measure the sheet — and so attach the floating chrome
  /// — once its scroll controller is attached, which only happens when the
  /// builder hands it to a scrollable. The loading/error/empty states are not
  /// lists, so without this the chrome would stay anchored to the previous
  /// sheet until the results appeared.
  Widget _message(ScrollController scrollController, Widget child) {
    return CustomScrollView(
      controller: scrollController,
      slivers: <Widget>[
        SliverFillRemaining(hasScrollBody: false, child: Center(child: child)),
      ],
    );
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
          onTap: () async {
            await ref.read(commandRegistryProvider).dispatch(
              'place.select',
              <String, Object?>{'id': place.id},
            );
            // The place sheet takes over: drop the category highlight (the pins
            // stay, exactly as when a search result is selected).
            ref.read(selectedCategoryProvider.notifier).select(null);
            // Leave the results route so the place sheet can appear on the map
            // (a no-op when the sheet is showing on the map home itself).
            if (context.mounted) {
              popOrHome(context);
            }
          },
        );
      },
    );
  }
}
