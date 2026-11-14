import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/place.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/home.dart';
import '../../../state/place.dart';
import '../../common/map_sheet.dart';
import '../../social/widgets/live_share_card.dart';

/// The draggable map-home sheet. Its content follows the active bottom-nav tab
/// (Explore / You / Contribute).
class HomeFeedSheet extends ConsumerWidget {
  const HomeFeedSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HomeTab tab = ref.watch(homeTabProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return MapSheet(
      initialChildSize: 0.16,
      minChildSize: 0.16,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const <double>[0.16, 0.42, 0.92],
      builder: (BuildContext context, ScrollController scrollController) {
        return Material(
          color: scheme.surface,
          elevation: 8,
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
              const _SheetHandle(),
              const SizedBox(height: AppSpacing.md),
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
    Text('Explore', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: AppSpacing.sm),
    const LiveShareCard(),
    const _FeedRow(icon: Icons.near_me_outlined, label: 'Nearby'),
    _FeedRow(
      icon: Icons.people_outline,
      label: 'Friends',
      onTap: () => context.push('/friends'),
    ),
    _FeedRow(
      icon: Icons.history,
      label: 'Recent',
      onTap: () => context.push('/search'),
    ),
    _FeedRow(
      icon: Icons.star_outline,
      label: 'Saved',
      onTap: () => context.push('/saved'),
    ),
  ];

  List<Widget> _you(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Place>> saved = ref.watch(bookmarksProvider);
    return <Widget>[
      Text('Saved places', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.sm),
      ...saved.when(
        loading: () => <Widget>[
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.hourglass_empty),
            title: Text('Loading saved places…'),
          ),
        ],
        error: (Object error, StackTrace stack) => <Widget>[
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.error_outline),
            title: Text('Could not load saved places'),
          ),
        ],
        data: (List<Place> places) => places.isEmpty
            ? <Widget>[
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.star_outline),
                  title: Text('No saved places yet'),
                ),
              ]
            : <Widget>[
                for (final Place place in places)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.star, color: Color(0xFFF9A825)),
                    title: Text(place.name),
                    subtitle: place.address == null
                        ? null
                        : Text(place.address!),
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
    Text('Contribute', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: AppSpacing.sm),
    const ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: false,
      leading: Icon(Icons.add_location_alt_outlined),
      title: Text('Contributions are not available yet'),
      subtitle: Text('Place suggestions and edits come later'),
    ),
  ];
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
