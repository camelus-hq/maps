import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../design/play.dart';

/// The draggable results sheet shown while browsing a category: the map stays
/// visible behind it with the nearby places highlighted, in the play style.
class CategoryResultsSheet extends ConsumerWidget {
  const CategoryResultsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayColors colors = PlayColors.of(context);
    final String? category = ref.watch(selectedCategoryProvider);
    final SearchState search = ref.watch(searchControllerProvider);
    return MapSheet(
      initialChildSize: 0.45,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const <double>[0.45, 0.9],
      builder: (BuildContext context, ScrollController scrollController) {
        return PlaySheet(
          child: Column(
            children: <Widget>[
              const PlaySheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  PlaySpace.lg,
                  0,
                  PlaySpace.sm,
                  PlaySpace.xs,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        category ?? 'Nearby',
                        style: PlayType.title.copyWith(color: colors.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PlayIconButton(
                      icon: PlayIcons.close,
                      variant: PlayIconButtonVariant.plain,
                      size: 44,
                      semanticLabel: 'Close',
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
    final PlayColors colors = PlayColors.of(context);
    switch (search.status) {
      case SearchStatus.loading:
        return _message(scrollController, const PlaySpinner());
      case SearchStatus.error:
        final ({IconData icon, String text}) presentation = errorPresentation(
          search.error,
          fallback: 'Could not load places',
        );
        return _message(
          scrollController,
          Padding(
            padding: const EdgeInsets.all(PlaySpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(presentation.icon, size: 34, color: colors.inkFaint),
                const SizedBox(height: PlaySpace.md),
                Text(
                  presentation.text,
                  textAlign: TextAlign.center,
                  style: PlayType.body.copyWith(color: colors.inkMuted),
                ),
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
            Padding(
              padding: const EdgeInsets.all(PlaySpace.lg),
              child: Text(
                'No places found nearby',
                style: PlayType.body.copyWith(color: colors.inkMuted),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: PlaySpace.lg),
      itemCount: places.length,
      separatorBuilder: (BuildContext context, int index) =>
          const PlayDivider(),
      itemBuilder: (BuildContext context, int index) {
        final Place place = places[index];
        final List<String> detail = <String>[?place.category, ?place.address];
        if (from != null) {
          detail.add(
            formatDistance(place.position.distanceTo(from), imperial: imperial),
          );
        }
        return PlayRow(
          icon: placeResultIcon(place.category),
          label: place.name,
          subtitle: detail.isEmpty ? null : detail.join(' · '),
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
