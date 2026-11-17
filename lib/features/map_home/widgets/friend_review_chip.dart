import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/review_marker.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/reviews.dart';
import '../../design/play.dart';

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
    final PlayColors colors = PlayColors.of(context);

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
    final PlayToneColors palette = colors.tone(
      friendOnly ? PlayTone.strong : PlayTone.neutral,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PlaySpace.lg),
      child: Align(
        alignment: Alignment.centerLeft,
        child: PlayChip(
          label: friendOnly ? "Friend's reviews" : "Friend's review",
          icon: friendOnly ? PlayIcons.filter : PlayIcons.friends,
          selected: friendOnly,
          onTap: () => unawaited(
            ref.read(commandRegistryProvider).dispatch(
              'map.reviews.friendOnly',
              <String, Object?>{'on': !friendOnly},
            ),
          ),
          trailing: Text(
            summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PlayType.caption.copyWith(
              color: palette.foreground.withValues(alpha: 0.72),
            ),
          ),
        ),
      ),
    );
  }
}
