import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/entities/review.dart';
import '../../../domain/entities/review_place.dart';
import '../../../domain/entities/review_summary.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/ports.dart';
import '../../../state/reviews.dart';
import '../../common/error_text.dart';
import 'review_tile.dart';

/// The reviews block inside the place sheet: the friend recommendation banner,
/// the headline review, the rest of the list and the "Write a review" entry
/// point.
///
/// Reviews are our own (Nostr kind 31987) — never Google's content.
class PlaceReviewsSection extends ConsumerStatefulWidget {
  const PlaceReviewsSection({
    super.key,
    required this.place,
    this.showTitle = true,
    this.writeButtonWhenEmpty = true,
  });

  final Place place;

  /// Draws the "Reviews" heading above the list. Off inside the place sheet's
  /// Reviews tab, where the tab label already names it.
  final bool showTitle;

  /// Offers "Be the first to review" when there are none. Off inside the sheet,
  /// where the header already shows the "Write a review" button while empty.
  final bool writeButtonWhenEmpty;

  @override
  ConsumerState<PlaceReviewsSection> createState() =>
      _PlaceReviewsSectionState();
}

class _PlaceReviewsSectionState extends ConsumerState<PlaceReviewsSection> {
  /// When true the list shows only reviews written by friends.
  bool _friendsOnly = false;

  @override
  Widget build(BuildContext context) {
    final String placeKey = ReviewPlace.keyFor(widget.place.id);
    final AsyncValue<List<Review>> async = ref.watch(
      placeReviewsProvider(placeKey),
    );
    final ThemeData theme = Theme.of(context);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace _) {
        final ({IconData icon, String text}) presentation = errorPresentation(
          error is AppException ? error : null,
          fallback: 'Could not load reviews',
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: <Widget>[
              Icon(
                presentation.icon,
                size: 20,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(presentation.text)),
              TextButton(
                onPressed: () => ref.invalidate(placeReviewsProvider(placeKey)),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
      data: (List<Review> _) =>
          _body(ref.watch(placeReviewSummaryProvider(placeKey))),
    );
  }

  Widget _body(ReviewSummary summary) {
    final ThemeData theme = Theme.of(context);
    if (summary.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('No reviews yet', style: theme.textTheme.bodyMedium),
            if (widget.writeButtonWhenEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _openComposer,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Be the first to review'),
              ),
            ],
          ],
        ),
      );
    }

    final List<Review> reviews = _friendsOnly
        ? summary.friendReviews
        : summary.reviews;
    final Review? headline = summary.headline;
    final List<Review> rest = <Review>[
      for (final Review review in reviews)
        if (review != headline) review,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (widget.showTitle)
              Expanded(
                child: Text('Reviews', style: theme.textTheme.titleMedium),
              )
            else
              const Spacer(),
            TextButton.icon(
              onPressed: _openComposer,
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: const Text('Write a review'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (summary.friendCount > 0)
          _FriendBanner(
            summary: summary,
            friendsOnly: _friendsOnly,
            onTap: () => setState(() => _friendsOnly = !_friendsOnly),
          ),
        if (headline != null)
          ReviewTile(
            review: headline,
            headline: true,
            onEdit: _isOwn(headline) ? _edit : null,
          ),
        for (final Review review in rest)
          ReviewTile(review: review, onEdit: _isOwn(review) ? _edit : null),
        if (_friendsOnly && reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text('No reviews from friends yet'),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Review average ${summary.stars.toStringAsFixed(1)} · '
          '${summary.reviewCount} ${summary.reviewCount == 1 ? 'review' : 'reviews'}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  void _openComposer() => unawaited(
    ref.read(commandRegistryProvider).dispatch(
      'review.compose',
      <String, Object?>{'id': widget.place.id},
    ),
  );

  void _edit(Review review) => unawaited(
    ref.read(commandRegistryProvider).dispatch(
      'review.compose',
      <String, Object?>{'id': widget.place.id},
    ),
  );

  bool _isOwn(Review review) =>
      ref.read(reviewServiceProvider).currentUserPubkey == review.authorPubkey;
}

/// The "Recommended by your friends" banner with the average and friend count.
class _FriendBanner extends StatelessWidget {
  const _FriendBanner({
    required this.summary,
    required this.friendsOnly,
    required this.onTap,
  });

  final ReviewSummary summary;
  final bool friendsOnly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int friends = summary.friendCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                Text(
                  summary.stars.toStringAsFixed(1),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        friendsOnly
                            ? 'Showing your friends’ reviews'
                            : 'Recommended by your friends',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        friends == 1
                            ? '1 friend has reviewed this place'
                            : '$friends friends have reviewed this place',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  friendsOnly ? Icons.expand_less : Icons.chevron_right,
                  color: scheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
