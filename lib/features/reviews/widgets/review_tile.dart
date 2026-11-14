import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../domain/entities/review.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/reviews.dart';
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
    this.headline = false,
    this.onEdit,
  });

  final Review review;

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
    final ThemeData theme = Theme.of(context);
    final Review review = widget.review;
    final String name = review.authorName ?? _shorten(review.authorPubkey);
    final String text = review.bodyText;
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
                            style: theme.textTheme.titleSmall,
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
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          formatTimeAgo(review.createdAt),
                          style: theme.textTheme.bodySmall,
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
                style: widget.headline
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.bodyMedium,
              ),
            ),
          if (review.photos.isNotEmpty) _photos(review),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              _pillAction(
                context,
                icon: _helpful ? Icons.thumb_up : Icons.thumb_up_outlined,
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
                icon: Icons.share_outlined,
                label: 'Share review',
                onTap: () => unawaited(_share(review)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photos(Review review) {
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
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFFE0E0E0),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: Icon(Icons.broken_image_outlined),
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
    return PopupMenuButton<String>(
      tooltip: 'Review options',
      icon: const Icon(Icons.more_horiz),
      onSelected: (String value) {
        if (value == 'edit') {
          widget.onEdit?.call(review);
        } else if (value == 'share') {
          _share(review);
        } else if (value == 'report') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thanks — this review was reported')),
          );
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        if (widget.onEdit != null)
          const PopupMenuItem<String>(
            value: 'edit',
            child: Text('Edit review'),
          ),
        const PopupMenuItem<String>(
          value: 'share',
          child: Text('Share review'),
        ),
        const PopupMenuItem<String>(value: 'report', child: Text('Report')),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color foreground = selected
        ? scheme.primary
        : scheme.onSurfaceVariant;
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: AppSpacing.xs),
              Text(label, style: TextStyle(fontSize: 12, color: foreground)),
            ],
          ),
        ),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Review copied')));
    }
  }

  static String _shorten(String pubkey) =>
      pubkey.length <= 10 ? pubkey : pubkey.substring(0, 8);
}

class _FriendBadge extends StatelessWidget {
  const _FriendBadge();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Friend',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
