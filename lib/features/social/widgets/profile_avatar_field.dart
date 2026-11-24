import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../../design/play.dart';

/// A picked, not-yet-published profile picture: the source bytes, its MIME
/// type and the zoom the user dialled in.
///
/// The bytes stay in memory only; [renderProfileAvatar] turns them into the
/// square PNG that is uploaded.
class AvatarDraft {
  const AvatarDraft({
    required this.bytes,
    required this.mimeType,
    this.zoom = 1,
  });

  final Uint8List bytes;
  final String mimeType;

  /// The zoom factor applied inside the square crop (1 = fit the short side).
  final double zoom;

  AvatarDraft copyWith({double? zoom}) =>
      AvatarDraft(bytes: bytes, mimeType: mimeType, zoom: zoom ?? this.zoom);
}

/// The fixed size (edge length in pixels) of the uploaded avatar.
const int profileAvatarSize = 512;

/// Renders [source] into a square, centre-cropped PNG at [size]×[size],
/// applying [zoom] so the user can frame their picture.
///
/// All drawing is local `dart:ui`; a decode failure throws, and the caller
/// shows a "could not read that image" message instead of crashing.
Future<Uint8List> renderProfileAvatar(
  Uint8List source, {
  double zoom = 1,
  int size = profileAvatarSize,
}) async {
  final ui.Codec codec = await ui.instantiateImageCodec(source);
  try {
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;
    try {
      final double factor = zoom.isFinite && zoom > 0 ? zoom : 1;
      final double side = math.min(image.width, image.height) / factor;
      final double left = (image.width - side) / 2;
      final double top = (image.height - side) / 2;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Size target = Size(size.toDouble(), size.toDouble());
      final Canvas canvas = Canvas(recorder, Offset.zero & target);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(left, top, side, side),
        Offset.zero & target,
        Paint()..filterQuality = FilterQuality.high,
      );
      final ui.Picture picture = recorder.endRecording();
      try {
        final ui.Image rendered = await picture.toImage(size, size);
        try {
          final ByteData? data = await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (data == null) {
            throw StateError('Could not encode the picture');
          }
          return data.buffer.asUint8List();
        } finally {
          rendered.dispose();
        }
      } finally {
        picture.dispose();
      }
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

/// A circular profile-picture editor: tap to pick a photo, pinch/drag the zoom
/// slider to frame it inside the circle, and watch the preview update.
///
/// The parent owns the [draft]; this widget only picks, zooms and previews it.
class ProfileAvatarField extends StatefulWidget {
  const ProfileAvatarField({
    super.key,
    required this.label,
    this.imageUrl,
    this.draft,
    required this.onChanged,
    this.busy = false,
  });

  /// Used for the monogram fallback while there is no picture.
  final String label;

  /// An already-published picture URL.
  final String? imageUrl;

  /// The newly picked picture, if any.
  final AvatarDraft? draft;

  /// Called with the new draft (or `null` when the picture is removed).
  final ValueChanged<AvatarDraft?> onChanged;

  /// Disables the controls while a save is in flight.
  final bool busy;

  @override
  State<ProfileAvatarField> createState() => _ProfileAvatarFieldState();
}

class _ProfileAvatarFieldState extends State<ProfileAvatarField> {
  final ImagePicker _picker = ImagePicker();
  bool _picking = false;

  Future<void> _pick() async {
    if (_picking || widget.busy) {
      return;
    }
    setState(() => _picking = true);
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) {
        return;
      }
      final Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (_) {
        if (mounted) {
          showPlayToast(context, 'Could not read that image');
        }
        return;
      }
      if (bytes.isEmpty) {
        if (mounted) {
          showPlayToast(context, 'Could not read that image');
        }
        return;
      }
      // Decode once up front so a corrupt/unsupported file is rejected here
      // rather than at upload time, and the zoom can be clamped to fit.
      try {
        final ui.Codec codec = await ui.instantiateImageCodec(bytes);
        codec.dispose();
      } catch (_) {
        if (mounted) {
          showPlayToast(context, 'That image format is not supported');
        }
        return;
      }
      if (mounted) {
        widget.onChanged(
          AvatarDraft(bytes: bytes, mimeType: _guessMime(file.name)),
        );
      }
    } catch (_) {
      if (mounted) {
        showPlayToast(context, 'Could not open the photo picker');
      }
    } finally {
      if (mounted) {
        setState(() => _picking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final AvatarDraft? draft = widget.draft;
    final bool hasPicture = draft != null || (widget.imageUrl ?? '').isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: ClipOval(child: _preview(context, draft)),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.line, width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: PlaySpace.sm),
        Center(
          child: Text(
            draft != null
                ? 'Drag to frame your picture'
                : (widget.imageUrl ?? '').isNotEmpty
                ? 'Tap a picture to change it'
                : 'Add a profile picture',
            style: PlayType.caption.copyWith(color: colors.inkMuted),
          ),
        ),
        if (draft != null) ...<Widget>[
          const SizedBox(height: PlaySpace.sm),
          Row(
            children: <Widget>[
              Icon(PlayIcons.zoomOut, size: 18, color: colors.inkMuted),
              const SizedBox(width: PlaySpace.sm),
              Expanded(
                child: _ZoomSlider(
                  value: draft.zoom.clamp(1, 3).toDouble(),
                  onChanged: widget.busy
                      ? null
                      : (double value) =>
                            widget.onChanged(draft.copyWith(zoom: value)),
                ),
              ),
              const SizedBox(width: PlaySpace.sm),
              Icon(PlayIcons.zoomIn, size: 18, color: colors.inkMuted),
            ],
          ),
        ],
        const SizedBox(height: PlaySpace.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            PlayButton(
              label: _picking
                  ? 'Opening…'
                  : (hasPicture ? 'Change photo' : 'Choose photo'),
              icon: PlayIcons.photo,
              variant: PlayButtonVariant.ghost,
              size: PlayButtonSize.sm,
              onPressed: (widget.busy || _picking) ? null : _pick,
            ),
            if (hasPicture) ...<Widget>[
              const SizedBox(width: PlaySpace.sm),
              PlayButton(
                label: 'Remove',
                icon: PlayIcons.close,
                variant: PlayButtonVariant.ghost,
                size: PlayButtonSize.sm,
                onPressed: widget.busy ? null : () => widget.onChanged(null),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _preview(BuildContext context, AvatarDraft? draft) {
    final PlayColors colors = PlayColors.of(context);
    if (draft != null) {
      return Transform.scale(
        scale: draft.zoom.clamp(1, 3).toDouble(),
        child: Image.memory(
          draft.bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
              _monogram(context),
        ),
      );
    }
    final String? url = widget.imageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
            _monogram(context),
        loadingBuilder: (
          BuildContext _,
          Widget child,
          ImageChunkEvent? progress,
        ) => progress == null ? child : _monogram(context),
      );
    }
    return ColoredBox(color: colors.primarySoft, child: _monogram(context));
  }

  Widget _monogram(BuildContext context) {
    final String trimmed = widget.label.trim();
    final String initial = trimmed.isEmpty
        ? '?'
        : String.fromCharCode(trimmed.runes.first).toUpperCase();
    return ColoredBox(
      color: PlayColors.of(context).primarySoft,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: PlayColors.of(context).onPrimarySoft,
            fontWeight: FontWeight.w700,
            fontSize: 48,
          ),
        ),
      ),
    );
  }

  static String _guessMime(String name) {
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
}

/// A Material-free zoom slider: a hairline track, a filled portion and a round
/// thumb, driven by taps and horizontal drags. Value range is 1…3.
class _ZoomSlider extends StatelessWidget {
  const _ZoomSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double>? onChanged;

  static const double _padding = 10;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final bool enabled = onChanged != null;
    return SizedBox(
      height: 40,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double travel = (constraints.maxWidth - _padding * 2).clamp(
            1,
            double.infinity,
          );
          void report(Offset local) {
            final ValueChanged<double>? cb = onChanged;
            if (cb == null) {
              return;
            }
            final double t = ((local.dx - _padding) / travel).clamp(0.0, 1.0);
            cb(1 + t * 2);
          }

          final double t = ((value - 1) / 2).clamp(0.0, 1.0);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (TapDownDetails d) => report(d.localPosition),
            onHorizontalDragStart: (DragStartDetails d) =>
                report(d.localPosition),
            onHorizontalDragUpdate: (DragUpdateDetails d) =>
                report(d.localPosition),
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _padding),
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.surfaceSunken,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _padding),
                    child: FractionallySizedBox(
                      widthFactor: t,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: _padding + travel * t - 10,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

@PlayPreview(name: 'ProfileAvatarField', size: Size(420, 320))
Widget profileAvatarFieldPreview() {
  return PlayPreviewFrame(
    child: ProfileAvatarField(label: 'You', onChanged: (AvatarDraft? _) {}),
  );
}
