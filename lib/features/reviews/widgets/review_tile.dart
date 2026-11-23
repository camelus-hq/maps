import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/format.dart';
import '../../../domain/entities/price_range.dart';
import '../../../domain/entities/review.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/reviews.dart';
import '../../design/play.dart';
import '../../social/widgets/friend_avatar.dart';
import 'star_rating.dart';

/// One review in the place sheet: author, stars, age, the text, any photos and
/// the Helpful / Share actions.
///
/// The headline review (a friend's, when there is one) uses the larger quote
/// styling from the reference sheet. Both actions go through commands
/// (`review.helpful`, `review.copy`), so an agent reaches them too.
class ReviewTile extends ConsumerStatefulWidget {
  const ReviewTile({
    super.key,
    required this.review,
    required this.currency,
    this.headline = false,
    this.onEdit,
  });

  final Review review;

  /// The place's currency, so the price chips read in the right region.
  final CurrencyInfo currency;

  /// Draws the review as the headline: bigger, quoted text.
  final bool headline;

  /// Called when the viewer chooses "Edit review" for their own review.
  final void Function(Review review)? onEdit;

  @override
  ConsumerState<ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends ConsumerState<ReviewTile> {
  /// Whether this review is marked helpful (session-local state).
  bool get _helpful =>
      ref.watch(helpfulReviewsProvider).contains(widget.review.id);

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final Review review = widget.review;
    final String name = review.authorName ?? _shorten(review.authorPubkey);
    final String text = review.bodyText;
    final CurrencyInfo reviewCurrency =
        currencyInfoForCode(review.priceCurrency) ?? widget.currency;
    final PriceRange? priceBand = review.priceBand(widget.currency);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FriendAvatar(
                label: name,
                pictureUrl: review.authorPicture,
                size: 40,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            name,
                            style: PlayType.bodyStrong.copyWith(
                              color: colors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (review.isFriend) ...<Widget>[
                          const SizedBox(width: AppSpacing.xs),
                          const _FriendBadge(),
                        ],
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        StarRating(value: review.stars, size: 14),
                        if (priceBand != null) ...<Widget>[
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            priceBand.shortLabel(reviewCurrency.symbol),
                            style: PlayType.caption.copyWith(
                              color: colors.inkMuted,
                            ),
                          ),
                        ],
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          formatTimeAgo(review.createdAt),
                          style: PlayType.caption.copyWith(
                            color: colors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _menu(context, review),
            ],
          ),
          if (text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                widget.headline ? '“$text”' : text,
                style: (widget.headline ? PlayType.title : PlayType.body)
                    .copyWith(color: colors.ink),
              ),
            ),
          if (review.photos.isNotEmpty) _photos(context, review),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              _pillAction(
                context,
                icon: _helpful
                    ? PhosphorIconsFill.thumbsUp
                    : PhosphorIconsRegular.thumbsUp,
                label: 'Helpful',
                selected: _helpful,
                onTap: () => unawaited(
                  ref.read(commandRegistryProvider).dispatch(
                    'review.helpful',
                    <String, Object?>{'id': review.id},
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _pillAction(
                context,
                icon: PlayIcons.share,
                label: 'Share review',
                onTap: () => unawaited(_share(review)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photos(BuildContext context, Review review) {
    final PlayColors colors = PlayColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: review.photos.length,
          separatorBuilder: (BuildContext _, int _) =>
              const SizedBox(width: AppSpacing.sm),
          itemBuilder: (BuildContext context, int index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                review.photos[index],
                width: 84,
                height: 84,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: const Color(0xFFE0E0E0),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: Icon(PlayIcons.brokenImage, color: colors.inkFaint),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _menu(BuildContext context, Review review) {
    return PlayMenuButton<String>(
      semanticLabel: 'Review options',
      icon: PlayIcons.more,
      onSelected: (String value) {
        if (value == 'edit') {
          widget.onEdit?.call(review);
        } else if (value == 'share') {
          unawaited(_share(review));
        } else if (value == 'report') {
          showPlayToast(context, 'Thanks — this review was reported');
        }
      },
      items: <PlayMenuItem<String>>[
        if (widget.onEdit != null)
          const PlayMenuItem<String>(value: 'edit', label: 'Edit review'),
        const PlayMenuItem<String>(value: 'share', label: 'Share review'),
        const PlayMenuItem<String>(value: 'report', label: 'Report'),
      ],
    );
  }

  Widget _pillAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    final PlayColors colors = PlayColors.of(context);
    final Color foreground = selected ? colors.primary : colors.inkMuted;
    return PlaySurface(
      radius: PlayRadii.pill,
      backgroundColor: colors.surfaceSunken,
      shadow: PlayShadow.none,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: PlayType.caption.copyWith(color: foreground)),
        ],
      ),
    );
  }

  Future<void> _share(Review review) async {
    final String name = review.authorName ?? _shorten(review.authorPubkey);
    final String text = review.bodyText.isEmpty
        ? '$name reviewed this place'
        : '$name: ${review.bodyText}';
    await ref.read(commandRegistryProvider).dispatch(
      'review.copy',
      <String, Object?>{'text': text},
    );
    if (mounted) {
      showPlayToast(context, 'Review copied');
    }
  }

  static String _shorten(String pubkey) =>
      pubkey.length <= 10 ? pubkey : pubkey.substring(0, 8);
}

class _FriendBadge extends StatelessWidget {
  const _FriendBadge();

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Friend',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: colors.onPrimarySoft,
        ),
      ),
    );
  }
}
