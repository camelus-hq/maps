import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/place.dart';
import '../../../state/place.dart';
import '../../../state/usecases.dart';
import '../../common/navigation.dart';

/// Lists saved (bookmarked) places; tapping one selects it on the map.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Place>> saved = ref.watch(bookmarksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: saved.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) => _Message(
          icon: Icons.error_outline,
          text: 'Could not load saved places',
          onRetry: () => ref.invalidate(bookmarksProvider),
        ),
        data: (List<Place> places) {
          if (places.isEmpty) {
            return const _Message(
              icon: Icons.star_outline,
              text: 'No saved places yet',
            );
          }
          return ListView.separated(
            itemCount: places.length,
            separatorBuilder: (BuildContext context, int index) =>
                const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final Place place = places[index];
              final String? address = place.address;
              return ListTile(
                leading: const Icon(Icons.star, color: Color(0xFFF9A825)),
                title: Text(place.name),
                subtitle: address == null ? null : Text(address),
                onTap: () {
                  ref.read(selectedPlaceProvider.notifier).select(place);
                  popOrHome(context);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove',
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
