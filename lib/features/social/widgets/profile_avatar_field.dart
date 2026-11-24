import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../../design/play.dart';

/// A picked, not-yet-published profile picture: the source bytes, its MIME
/// type, the zoom the user dialled in and how far they dragged it (both
/// normalised to the square preview, so they are resolution-independent).
///
/// The bytes stay in memory only; [renderProfileAvatar] turns them into the
/// square PNG that is uploaded.
class AvatarDraft {
  const AvatarDraft({
    required this.bytes,
    required this.mimeType,
    this.zoom = 1,
    this.offset = Offset.zero,
    required this.aspectRatio,
  });

  final Uint8List bytes;
  final String mimeType;

  /// The zoom factor applied inside the square crop (1 = fit the short side).
  final double zoom;

  /// The pan, in fractions of the preview square's side (so the same drag
  /// shows the same crop at any display size).
  final Offset offset;

  /// The source image's width / height, used to clamp the pan so the picture
  /// always covers the circle.
  final double aspectRatio;

  AvatarDraft copyWith({double? zoom, Offset? offset}) => AvatarDraft(
    bytes: bytes,
    mimeType: mimeType,
    zoom: zoom ?? this.zoom,
    offset: offset ?? this.offset,
    aspectRatio: aspectRatio,
  );
}

/// The fixed size (edge length in pixels) of the uploaded avatar.
const int profileAvatarSize = 512;

/// The display size of the circular preview.
const double _previewSize = 132;

/// Keeps a normalised pan offset inside the range where the (zoomed) picture
/// still covers the square, for an image of [aspectRatio] (w/h).
Offset clampAvatarOffset(
  Offset offset, {
  required double zoom,
  required double aspectRatio,
}) {
  final double z = zoom.isFinite && zoom > 0 ? zoom : 1;
  final double ar = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 1;
  final double maxX = (math.max(1, ar) * z - 1) / 2;
  final double maxY = (math.max(1, 1 / ar) * z - 1) / 2;
  return Offset(
    offset.dx.clamp(-maxX, maxX).toDouble(),
    offset.dy.clamp(-maxY, maxY).toDouble(),
  );
}

/// Renders [source] into a square, centre-cropped PNG at [size]×[size],
/// applying [zoom] and [offset] so the user can frame their picture.
///
/// All drawing is local `dart:ui`; a decode failure throws, and the caller
/// shows a "could not read that image" message instead of crashing.
Future<Uint8List> renderProfileAvatar(
  Uint8List source, {
  double zoom = 1,
  Offset offset = Offset.zero,
  int size = profileAvatarSize,
}) async {
  final ui.Codec codec = await ui.instantiateImageCodec(source);
  try {
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;
    try {
      final double w = image.width.toDouble();
      final double h = image.height.toDouble();
      final double factor = zoom.isFinite && zoom > 0 ? zoom : 1;
      final double cover = math.max(size / w, size / h);
      final double scale = cover * factor;
      final Offset pan = clampAvatarOffset(
        offset,
        zoom: factor,
        aspectRatio: w / h,
      );
      final double target = size.toDouble();

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(
        recorder,
        Offset.zero & Size(target, target),
      );
      canvas.save();
      canvas.translate(
        target / 2 + pan.dx * target,
        target / 2 + pan.dy * target,
      );
      canvas.scale(scale);
      canvas.translate(-w / 2, -h / 2);
      canvas.drawImage(
        image,
        Offset.zero,
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.restore();
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

/// A circular profile-picture editor: tap to pick a photo, **drag** the picture
/// to reposition it and use the zoom slider to size it, with the preview
/// updating live.
///
/// The parent owns the [draft]; this widget only picks, zooms, drags and
/// previews it.
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

  // The pan at the start of a drag, so each update is absolute (no drift).
  Offset? _dragStart;

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
      // rather than at upload time, and the pan can be clamped to fit.
      final ui.Image decoded;
      try {
        final ui.Codec codec = await ui.instantiateImageCodec(bytes);
        try {
          decoded = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      } catch (_) {
        if (mounted) {
          showPlayToast(context, 'That image format is not supported');
        }
        return;
      }
      final double aspect = decoded.height == 0
          ? 1
          : decoded.width / decoded.height;
      decoded.dispose();
      if (mounted) {
        widget.onChanged(
          AvatarDraft(
            bytes: bytes,
            mimeType: _guessMime(file.name),
            aspectRatio: aspect,
          ),
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

  void _onPanStart(DragStartDetails details, AvatarDraft draft) {
    _dragStart = draft.offset;
  }

  void _onPanUpdate(DragUpdateDetails details, AvatarDraft draft) {
    if (widget.busy) {
      return;
    }
    final Offset start = _dragStart ?? draft.offset;
    final Offset next = Offset(
      start.dx + details.delta.dx / _previewSize,
      start.dy + details.delta.dy / _previewSize,
    );
    _dragStart = next;
    widget.onChanged(
      draft.copyWith(
        offset: clampAvatarOffset(
          next,
          zoom: draft.zoom,
          aspectRatio: draft.aspectRatio,
        ),
      ),
    );
  }

  void _onPanEnd() => _dragStart = null;

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
            width: _previewSize,
            height: _previewSize,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: ClipOval(
                    child: draft == null
                        ? _staticPreview(context)
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (DragStartDetails d) =>
                                _onPanStart(d, draft),
                            onPanUpdate: (DragUpdateDetails d) =>
                                _onPanUpdate(d, draft),
                            onPanEnd: (DragEndDetails _) => _onPanEnd(),
                            child: _draftPreview(draft),
                          ),
                  ),
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
                ? 'Drag to move, slide to zoom'
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
                      : (double value) {
                          final double zoom = value.clamp(1, 3).toDouble();
                          widget.onChanged(
                            draft.copyWith(
                              zoom: zoom,
                              offset: clampAvatarOffset(
                                draft.offset,
                                zoom: zoom,
                                aspectRatio: draft.aspectRatio,
                              ),
                            ),
                          );
                        },
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

  /// The zoomed-and-panned picture, on a cover fit, clipped to the circle.
  Widget _draftPreview(AvatarDraft draft) {
    final double zoom = draft.zoom.clamp(1, 3).toDouble();
    return Transform.translate(
      offset: Offset(
        draft.offset.dx * _previewSize,
        draft.offset.dy * _previewSize,
      ),
      child: Transform.scale(
        scale: zoom,
        child: Image.memory(
          draft.bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
              _monogram(context),
        ),
      ),
    );
  }

  /// The published picture (or monogram) when no draft is being edited.
  Widget _staticPreview(BuildContext context) {
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
    return ColoredBox(
      color: PlayColors.of(context).primarySoft,
      child: _monogram(context),
    );
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
