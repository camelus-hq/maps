import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/entities/review.dart';
import '../../../domain/entities/review_place.dart';
import '../../../domain/entities/review_summary.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/ports.dart';
import '../../../state/reviews.dart';
import '../../common/error_text.dart';
import '../../common/shimmer.dart';
import '../../design/play.dart';
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
    return async.when(
      loading: () => const _ReviewsLoadingSkeleton(),
      error: (Object error, StackTrace _) {
        final PlayColors colors = PlayColors.of(context);
        final ({IconData icon, String text}) presentation = errorPresentation(
          error is AppException ? error : null,
          fallback: 'Could not load reviews',
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: <Widget>[
              Icon(presentation.icon, size: 20, color: colors.inkFaint),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  presentation.text,
                  style: PlayType.body.copyWith(color: colors.ink),
                ),
              ),
              PlayButton(
                label: 'Retry',
                variant: PlayButtonVariant.ghost,
                size: PlayButtonSize.sm,
                onPressed: () => ref.invalidate(placeReviewsProvider(placeKey)),
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
    final PlayColors colors = PlayColors.of(context);
    if (summary.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'No reviews yet',
              style: PlayType.body.copyWith(color: colors.ink),
            ),
            if (widget.writeButtonWhenEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              PlayButton(
                label: 'Be the first to review',
                icon: PlayIcons.review,
                variant: PlayButtonVariant.ghost,
                size: PlayButtonSize.sm,
                onPressed: _openComposer,
              ),
            ],
          ],
        ),
      );
    }

    final List<Review> reviews = _friendsOnly
        ? summary.friendReviews
        : summary.reviews;
    final CurrencyInfo currency = currencyForRegion(widget.place.regionCode);
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
                child: Text(
                  'Reviews',
                  style: PlayType.title.copyWith(color: colors.ink),
                ),
              )
            else
              const Spacer(),
            PlayButton(
              label: 'Write a review',
              icon: PlayIcons.review,
              variant: PlayButtonVariant.ghost,
              size: PlayButtonSize.sm,
              onPressed: _openComposer,
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
            currency: currency,
            headline: true,
            onEdit: _isOwn(headline) ? _edit : null,
          ),
        for (final Review review in rest)
          ReviewTile(
            review: review,
            currency: currency,
            onEdit: _isOwn(review) ? _edit : null,
          ),
        if (_friendsOnly && reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              'No reviews from friends yet',
              style: PlayType.body.copyWith(color: colors.ink),
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Review average ${summary.stars.toStringAsFixed(1)} · '
          '${summary.reviewCount} ${summary.reviewCount == 1 ? 'review' : 'reviews'}',
          style: PlayType.caption.copyWith(color: colors.inkMuted),
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

/// The shimmering stand-in for the review list while reviews load.
class _ReviewsLoadingSkeleton extends StatelessWidget {
  const _ReviewsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          for (int i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ShimmerBox(height: 40, circle: true),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ShimmerBox(width: 120, height: 14),
                        SizedBox(height: AppSpacing.sm),
                        ShimmerBox(width: 80, height: 12),
                        SizedBox(height: AppSpacing.sm),
                        ShimmerBox(height: 12),
                        SizedBox(height: AppSpacing.xs),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.6,
                          child: ShimmerBox(height: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
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
    final PlayColors colors = PlayColors.of(context);
    final int friends = summary.friendCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PlaySurface(
        tone: PlayTone.soft,
        radius: PlayRadii.md,
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Text(
              summary.stars.toStringAsFixed(1),
              style: PlayType.headline.copyWith(color: colors.onPrimarySoft),
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
                    style: PlayType.bodyStrong.copyWith(
                      color: colors.onPrimarySoft,
                    ),
                  ),
                  Text(
                    friends == 1
                        ? '1 friend has reviewed this place'
                        : '$friends friends have reviewed this place',
                    style: PlayType.caption.copyWith(
                      color: colors.onPrimarySoft,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              friendsOnly ? PhosphorIconsRegular.caretUp : PlayIcons.next,
              color: colors.onPrimarySoft,
            ),
          ],
        ),
      ),
    );
  }
}
