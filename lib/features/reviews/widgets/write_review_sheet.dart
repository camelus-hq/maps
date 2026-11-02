import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/entities/review.dart';
import '../../../domain/entities/review_draft.dart';
import '../../../state/reviews.dart';
import '../widgets/star_rating.dart';

/// The "Write a review" sheet (reference: the review composer).
///
/// Everything it does is also a command id (`review.compose`, `review.draft.set`,
/// `review.photo.add`, `review.publish`), so an agent can drive it without a
/// single gesture. The widget itself holds only the text controller; the draft
/// lives in [reviewComposerProvider].
class WriteReviewSheet extends ConsumerStatefulWidget {
  const WriteReviewSheet({super.key});

  @override
  ConsumerState<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<WriteReviewSheet> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _pickingPhotos = false;

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(reviewComposerProvider).draft?.text ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ReviewComposerState composer = ref.watch(reviewComposerProvider);

    // A successful publish closes the sheet and confirms it.
    ref.listen<ReviewComposerState>(reviewComposerProvider, (
      ReviewComposerState? _,
      ReviewComposerState next,
    ) {
      if (next.isPublished) {
        ref.read(reviewComposerProvider.notifier).close();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Review published')));
      }
    });

    final Place? place = composer.place;
    if (place == null) {
      return const SizedBox.shrink();
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // The map-home Scaffold deliberately does not resize for the keyboard (the
    // map must not move), so the composer lifts itself above it instead: the
    // reduced height keeps the focused field and the Publish button reachable.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.9,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const <double>[0.9, 0.95],
        builder: (BuildContext context, ScrollController scrollController) {
          return Material(
            color: scheme.surface,
            elevation: 12,
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
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _header(context, place),
                const SizedBox(height: AppSpacing.lg),
                _rating(context, composer),
                const SizedBox(height: AppSpacing.lg),
                _reviewField(context, composer),
                const SizedBox(height: AppSpacing.md),
                _photosRow(context, composer),
                const SizedBox(height: AppSpacing.md),
                _visibilityRow(context, composer),
                const SizedBox(height: AppSpacing.xl),
                _publishButton(context, composer),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: Text(
                    'You can edit your review anytime.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, Place place) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                place.name,
                style: theme.textTheme.headlineSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (place.category != null || place.address != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    <String>[
                      if (place.category != null) place.category!,
                      if (place.address != null) place.address!,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => ref.read(reviewComposerProvider.notifier).close(),
        ),
      ],
    );
  }

  Widget _rating(BuildContext context, ReviewComposerState composer) {
    final ThemeData theme = Theme.of(context);
    final int stars = composer.stars;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('How was your visit?', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            StarRatingInput(
              value: stars,
              onChanged: (int value) {
                if (value == 0) {
                  ref.read(reviewComposerProvider.notifier).setRating(0);
                } else {
                  ref.read(reviewComposerProvider.notifier).setStars(value);
                }
              },
            ),
            const SizedBox(width: AppSpacing.sm),
            if (stars > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _ratingLabel(stars),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text('$stars out of 5', style: theme.textTheme.bodySmall),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _reviewField(BuildContext context, ReviewComposerState composer) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Your review', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _controller,
          minLines: 4,
          maxLines: 8,
          maxLength: ReviewDraft.maxTextLength,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: 'Share details of your own experience at this place',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (String value) =>
              ref.read(reviewComposerProvider.notifier).setText(value),
          buildCounter:
              (
                BuildContext context, {
                required int currentLength,
                required int? maxLength,
                required bool isFocused,
              }) {
                return Text(
                  '$currentLength / ${_group(maxLength ?? 0)}',
                  style: theme.textTheme.bodySmall,
                );
              },
        ),
      ],
    );
  }

  Widget _photosRow(BuildContext context, ReviewComposerState composer) {
    final ReviewDraft? draft = composer.draft;
    if (draft == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: composer.isPublishing ? null : _pickPhotos,
          icon: _pickingPhotos
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_a_photo_outlined),
          label: const Text('Add photos'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            alignment: Alignment.centerLeft,
          ),
        ),
        if (draft.photoCount > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 72,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (int i = 0; i < draft.photos.length; i++)
                  _photoPreview(
                    bytes: draft.photos[i].data,
                    onRemove: () => ref
                        .read(reviewComposerProvider.notifier)
                        .removePhotoAt(i),
                  ),
                for (int i = 0; i < draft.photoUrls.length; i++)
                  _photoPreview(
                    url: draft.photoUrls[i],
                    onRemove: () => ref
                        .read(reviewComposerProvider.notifier)
                        .removePhotoUrlAt(i),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _photoPreview({
    Uint8List? bytes,
    String? url,
    required VoidCallback onRemove,
  }) {
    final ImageProvider<Object>? image = bytes != null
        ? MemoryImage(bytes)
        : (url != null ? NetworkImage(url) : null);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Stack(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 72,
              height: 72,
              child: image == null
                  ? const ColoredBox(color: Color(0xFFE0E0E0))
                  : Image(
                      image: image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Color(0xFFE0E0E0),
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: IconButton(
              iconSize: 16,
              icon: const Icon(Icons.cancel),
              tooltip: 'Remove photo',
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }

  Widget _visibilityRow(BuildContext context, ReviewComposerState composer) {
    final ReviewVisibility visibility =
        composer.draft?.visibility ?? ReviewVisibility.public;
    final bool friends = visibility == ReviewVisibility.friends;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(friends ? Icons.people_outline : Icons.public),
      title: Text(friends ? 'Share with friends' : 'Public review'),
      subtitle: Text(
        friends
            ? 'Only your friends can see this review.'
            : 'Anyone can see this review.',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: composer.isPublishing ? null : () => _chooseVisibility(visibility),
    );
  }

  Future<void> _chooseVisibility(ReviewVisibility current) async {
    final ReviewVisibility? choice =
        await showModalBottomSheet<ReviewVisibility>(
          context: context,
          showDragHandle: true,
          builder: (BuildContext context) => SafeArea(
            child: RadioGroup<ReviewVisibility>(
              groupValue: current,
              onChanged: (ReviewVisibility? value) =>
                  Navigator.of(context).pop(value),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  RadioListTile<ReviewVisibility>(
                    value: ReviewVisibility.public,
                    title: Text('Public review'),
                    subtitle: Text('Anyone can see this review.'),
                  ),
                  RadioListTile<ReviewVisibility>(
                    value: ReviewVisibility.friends,
                    title: Text('Share with friends'),
                    subtitle: Text('Only your friends can see this review.'),
                  ),
                ],
              ),
            ),
          ),
        );
    if (choice == null || !mounted) {
      return;
    }
    ref.read(reviewComposerProvider.notifier).setVisibility(choice);
  }

  Widget _publishButton(BuildContext context, ReviewComposerState composer) {
    final ReviewDraft? draft = composer.draft;
    final bool canPublish = draft?.canPublish ?? false;
    final bool friendsOnly = draft?.visibility == ReviewVisibility.friends;
    final String? error = composer.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (friendsOnly)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Friends-only reviews are not available yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton.icon(
          onPressed: (canPublish && !composer.isPublishing)
              ? () => unawaited(
                  ref.read(reviewComposerProvider.notifier).publish(),
                )
              : null,
          icon: composer.isPublishing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Publish review'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      ],
    );
  }

  Future<void> _pickPhotos() async {
    if (_pickingPhotos) {
      return;
    }
    setState(() => _pickingPhotos = true);
    try {
      final List<XFile> files = await _picker.pickMultiImage();
      final List<ReviewPhoto> photos = <ReviewPhoto>[];
      for (final XFile file in files.take(ReviewDraft.maxPhotos)) {
        try {
          final Uint8List bytes = await file.readAsBytes();
          if (bytes.isEmpty) {
            continue;
          }
          photos.add(
            ReviewPhoto(
              data: bytes,
              mimeType: file.mimeType ?? _guessMime(file.name),
              filename: file.name,
            ),
          );
        } catch (_) {
          // One unreadable file must not lose the others.
        }
      }
      if (!mounted) {
        return;
      }
      ref.read(reviewComposerProvider.notifier).addPhotos(photos);
      if (photos.isEmpty && files.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read that photo')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the photo picker')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pickingPhotos = false);
      }
    }
  }

  static String? _guessMime(String name) {
    final String lower = name.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.heic')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }

  static String _ratingLabel(int stars) => switch (stars) {
    1 => 'Poor',
    2 => 'Fair',
    3 => 'Good',
    4 => 'Great',
    _ => 'Excellent',
  };

  static String _group(int value) {
    final String digits = value.toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
