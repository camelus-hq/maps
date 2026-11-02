import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/review_marker.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/reviews.dart';

/// The "Friend's review" chip on the map, shown when at least one place on
/// screen has been reviewed by a friend.
///
/// It carries the friend average ("★ 4.8 · 3 friends") and toggles the map to
/// draw only friend-reviewed places — the same command (`map.reviews.friendOnly`)
/// an agent drives.
class FriendReviewChip extends ConsumerWidget {
  const FriendReviewChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<ReviewMarker> friends = ref.watch(friendReviewMarkersProvider);
    if (friends.isEmpty) {
      return const SizedBox.shrink();
    }
    final bool friendOnly = ref.watch(friendReviewsOnlyProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    double sum = 0;
    int reviews = 0;
    for (final ReviewMarker marker in friends) {
      sum += marker.averageRating * marker.reviewCount;
      reviews += marker.reviewCount;
    }
    final double average = reviews == 0 ? 0 : sum / reviews;
    final String summary = reviews == 0
        ? '${friends.length} places'
        : '★ ${(average * 5).toStringAsFixed(1)} · '
              '${friends.length} ${friends.length == 1 ? 'place' : 'places'}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: friendOnly ? scheme.primary : scheme.surface,
          elevation: 2,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => unawaited(
              ref.read(commandRegistryProvider).dispatch(
                'map.reviews.friendOnly',
                <String, Object?>{'on': !friendOnly},
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    friendOnly ? Icons.filter_alt : Icons.people_alt_outlined,
                    size: 16,
                    color: friendOnly ? scheme.onPrimary : scheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      friendOnly ? "Friend's reviews" : "Friend's review",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: friendOnly ? scheme.onPrimary : scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: friendOnly
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
