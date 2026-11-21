import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/place.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/home.dart';
import '../../../state/place.dart';
import '../../common/map_sheet.dart';
import '../../design/play.dart';
import '../../social/widgets/live_share_card.dart';

/// The draggable map-home sheet. Its content follows the active bottom-nav tab
/// (Explore / You / Contribute), on the play sheet surface.
class HomeFeedSheet extends ConsumerWidget {
  const HomeFeedSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HomeTab tab = ref.watch(homeTabProvider);
    return MapSheet(
      initialChildSize: 0.16,
      minChildSize: 0.16,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const <double>[0.16, 0.42, 0.92],
      builder: (BuildContext context, ScrollController scrollController) {
        return PlaySheet(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              PlaySpace.lg,
              0,
              PlaySpace.lg,
              PlaySpace.lg,
            ),
            children: <Widget>[
              // First child of the scroll view, so it also drags the sheet.
              const PlaySheetHandle(),
              const SizedBox(height: PlaySpace.sm),
              ..._content(context, ref, tab),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, HomeTab tab) =>
      switch (tab) {
        HomeTab.explore => _explore(context),
        HomeTab.you => _you(context, ref),
        HomeTab.contribute => _contribute(context),
      };

  List<Widget> _explore(BuildContext context) => <Widget>[
    _heading(context, 'Explore'),
    const SizedBox(height: PlaySpace.sm),
    const LiveShareCard(),
    const PlayRow(icon: PlayIcons.nearby, label: 'Nearby'),
    PlayRow(
      icon: PlayIcons.friends,
      label: 'Friends',
      onTap: () => context.push('/friends'),
    ),
    PlayRow(
      icon: PlayIcons.recent,
      label: 'Recent',
      onTap: () => context.push('/search'),
    ),
    PlayRow(
      icon: PlayIcons.route,
      label: 'Recent trips',
      onTap: () => context.push('/trips'),
    ),
    PlayRow(
      icon: PlayIcons.saved,
      label: 'Saved',
      onTap: () => context.push('/saved'),
    ),
  ];

  List<Widget> _you(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Place>> saved = ref.watch(bookmarksProvider);
    return <Widget>[
      _heading(context, 'Saved places'),
      const SizedBox(height: PlaySpace.sm),
      ...saved.when(
        loading: () => <Widget>[
          const PlayRow(
            icon: PlayIcons.loading,
            label: 'Loading saved places…',
          ),
        ],
        error: (Object error, StackTrace stack) => <Widget>[
          const PlayRow(
            icon: PlayIcons.error,
            label: 'Could not load saved places',
          ),
        ],
        data: (List<Place> places) => places.isEmpty
            ? <Widget>[
                const PlayRow(
                  icon: PlayIcons.saved,
                  label: 'No saved places yet',
                ),
              ]
            : <Widget>[
                for (final Place place in places)
                  PlayRow(
                    icon: PlayIcons.savedFilled,
                    label: place.name,
                    subtitle: place.address,
                    onTap: () => unawaited(
                      ref.read(commandRegistryProvider).dispatch(
                        'place.select',
                        <String, Object?>{'id': place.id},
                      ),
                    ),
                  ),
              ],
      ),
    ];
  }

  List<Widget> _contribute(BuildContext context) => <Widget>[
    _heading(context, 'Contribute'),
    const SizedBox(height: PlaySpace.sm),
    const PlayRow(
      icon: PlayIcons.contributePlace,
      label: 'Contributions are not available yet',
      subtitle: 'Place suggestions and edits come later',
      enabled: false,
    ),
  ];

  Widget _heading(BuildContext context, String text) => Text(
    text,
    style: PlayType.headline.copyWith(color: PlayColors.of(context).ink),
  );
}
