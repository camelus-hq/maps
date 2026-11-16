import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/place.dart';
import '../../../state/place.dart';
import '../../../state/usecases.dart';
import '../../common/navigation.dart';
import '../../design/play.dart';

/// Lists saved (bookmarked) places; tapping one selects it on the map.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Place>> saved = ref.watch(bookmarksProvider);
    return PlayScaffold(
      appBar: const PlayAppBar(title: 'Saved'),
      child: saved.when(
        loading: () => const Center(child: PlaySpinner()),
        error: (Object error, StackTrace stack) => _Message(
          icon: PlayIcons.error,
          text: 'Could not load saved places',
          onRetry: () => ref.invalidate(bookmarksProvider),
        ),
        data: (List<Place> places) {
          if (places.isEmpty) {
            return const _Message(
              icon: PlayIcons.saved,
              text: 'No saved places yet',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: PlaySpace.lg,
              vertical: PlaySpace.sm,
            ),
            itemCount: places.length,
            separatorBuilder: (BuildContext context, int index) =>
                const PlayDivider(),
            itemBuilder: (BuildContext context, int index) {
              final Place place = places[index];
              return PlayRow(
                icon: PlayIcons.savedFilled,
                label: place.name,
                subtitle: place.address,
                onTap: () {
                  ref.read(selectedPlaceProvider.notifier).select(place);
                  popOrHome(context);
                },
                trailing: PlayIconButton(
                  icon: PlayIcons.close,
                  variant: PlayIconButtonVariant.plain,
                  size: 40,
                  semanticLabel: 'Remove',
                  onPressed: () => unawaited(_remove(ref, place)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _remove(WidgetRef ref, Place place) async {
    await ref.read(toggleBookmarkProvider)(place, bookmarked: false);
    await ref.read(savedMarkersProvider.notifier).refresh();
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
