import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/entities/review.dart';
import '../../../domain/entities/review_draft.dart';
import '../../../state/reviews.dart';
import '../../common/map_sheet.dart';
import '../../design/play.dart';
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
  final FocusNode _focus = FocusNode();
  final ImagePicker _picker = ImagePicker();
  bool _pickingPhotos = false;

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(reviewComposerProvider).draft?.text ?? '';
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Rebuilds so the hint and the character counter follow the text.
  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
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
        showPlayToast(context, 'Review published');
      }
    });

    final Place? place = composer.place;
    if (place == null) {
      return const SizedBox.shrink();
    }
    // The map-home Scaffold deliberately does not resize for the keyboard (the
    // map must not move), so the composer lifts itself above it instead: the
    // reduced height keeps the focused field and the Publish button reachable.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: MapSheet(
        initialChildSize: 0.9,
        minChildSize: 0.9,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const <double>[0.9, 0.95],
        builder: (BuildContext context, ScrollController scrollController) {
          return PlaySheet(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              children: <Widget>[
                const PlaySheetHandle(),
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
                    style: PlayType.caption.copyWith(
                      color: PlayColors.of(context).inkMuted,
                    ),
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
    final PlayColors colors = PlayColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                place.name,
                style: PlayType.headline.copyWith(color: colors.ink),
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
                    style: PlayType.caption.copyWith(color: colors.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        PlayIconButton(
          icon: PlayIcons.close,
          semanticLabel: 'Close',
          size: 40,
          onPressed: () => ref.read(reviewComposerProvider.notifier).close(),
        ),
      ],
    );
  }

  Widget _rating(BuildContext context, ReviewComposerState composer) {
    final PlayColors colors = PlayColors.of(context);
    final int stars = composer.stars;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'How was your visit?',
          style: PlayType.title.copyWith(color: colors.ink),
        ),
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
                    style: PlayType.bodyStrong.copyWith(color: colors.primary),
                  ),
                  Text(
                    '$stars out of 5',
                    style: PlayType.caption.copyWith(color: colors.inkMuted),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _reviewField(BuildContext context, ReviewComposerState composer) {
    final PlayColors colors = PlayColors.of(context);
    final bool hasText = _controller.text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Your review', style: PlayType.title.copyWith(color: colors.ink)),
        const SizedBox(height: AppSpacing.sm),
        PlaySurface(
          radius: PlayRadii.md,
          borderWidth: 1,
          shadow: PlayShadow.none,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  if (!hasText)
                    Text(
                      'Share details of your own experience at this place',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PlayType.body.copyWith(color: colors.inkFaint),
                    ),
                  EditableText(
                    controller: _controller,
                    focusNode: _focus,
                    style: PlayType.body.copyWith(color: colors.ink),
                    cursorColor: colors.primary,
                    backgroundCursorColor: colors.inkFaint,
                    selectionColor: colors.primary.withValues(alpha: 0.25),
                    minLines: 4,
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    inputFormatters: <TextInputFormatter>[
                      LengthLimitingTextInputFormatter(
                        ReviewDraft.maxTextLength,
                      ),
                    ],
                    onChanged: (String value) => ref
                        .read(reviewComposerProvider.notifier)
                        .setText(value),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_controller.text.length} / '
                  '${_group(ReviewDraft.maxTextLength)}',
                  style: PlayType.caption.copyWith(color: colors.inkMuted),
                ),
              ),
            ],
          ),
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
        PlayButton(
          label: 'Add photos',
          icon: _pickingPhotos
              ? PlayIcons.loading
              : PhosphorIconsRegular.camera,
          variant: PlayButtonVariant.ghost,
          expand: true,
          onPressed: composer.isPublishing ? null : _pickPhotos,
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
    final PlayColors colors = PlayColors.of(context);
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
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: const Color(0xFFE0E0E0),
                        child: Icon(
                          PlayIcons.brokenImage,
                          color: colors.inkFaint,
                        ),
                      ),
                    ),
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: PlayIconButton(
              icon: PlayIcons.close,
              variant: PlayIconButtonVariant.plain,
              size: 32,
              iconSize: 16,
              semanticLabel: 'Remove photo',
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
    return PlayRow(
      icon: friends ? PlayIcons.friends : PlayIcons.globe,
      label: friends ? 'Share with friends' : 'Public review',
      subtitle: friends
          ? 'Only your friends can see this review.'
          : 'Anyone can see this review.',
      onTap: composer.isPublishing ? null : () => _chooseVisibility(visibility),
    );
  }

  Future<void> _chooseVisibility(ReviewVisibility current) async {
    final ReviewVisibility? choice = await showPlaySheet<ReviewVisibility>(
      context,
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PlayRow(
              leading: PlayRadio(selected: current == ReviewVisibility.public),
              label: 'Public review',
              subtitle: 'Anyone can see this review.',
              showChevron: false,
              onTap: () => Navigator.of(context).pop(ReviewVisibility.public),
            ),
            PlayRow(
              leading: PlayRadio(selected: current == ReviewVisibility.friends),
              label: 'Share with friends',
              subtitle: 'Only your friends can see this review.',
              showChevron: false,
              onTap: () => Navigator.of(context).pop(ReviewVisibility.friends),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) {
      return;
    }
    ref.read(reviewComposerProvider.notifier).setVisibility(choice);
  }

  Widget _publishButton(BuildContext context, ReviewComposerState composer) {
    final PlayColors colors = PlayColors.of(context);
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
              style: TextStyle(color: colors.coral, fontSize: 12),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.coral),
            ),
          ),
        PlayButton(
          label: 'Publish review',
          icon: PlayIcons.check,
          size: PlayButtonSize.lg,
          expand: true,
          onPressed: (canPublish && !composer.isPublishing)
              ? () => unawaited(
                  ref.read(reviewComposerProvider.notifier).publish(),
                )
              : null,
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
        showPlayToast(context, 'Could not read that photo');
      }
    } catch (_) {
      if (mounted) {
        showPlayToast(context, 'Could not open the photo picker');
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
