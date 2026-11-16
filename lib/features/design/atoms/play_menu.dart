import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../play_icons.dart';
import '../play_previews.dart';
import 'play_icon_button.dart';
import 'play_pressable.dart';
import 'play_surface.dart';

/// One entry in a [PlayMenuButton].
@immutable
class PlayMenuItem<T> {
  const PlayMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.tone = PlayTone.neutral,
  });

  final T value;
  final String label;
  final IconData? icon;
  final PlayTone tone;
}

/// A small popup menu anchored to an icon button — the play replacement for
/// Material's `PopupMenuButton`.
///
/// The overlay is laid out with a [CustomSingleChildLayout] that keeps it on
/// screen: it opens below the button, flips above it when there is no room, and
/// is clamped to the viewport with a margin on both axes. A tap outside
/// dismisses it.
class PlayMenuButton<T> extends StatefulWidget {
  const PlayMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    this.icon = PlayIcons.more,
    this.semanticLabel = 'More',
    this.variant = PlayIconButtonVariant.plain,
    this.size = 40,
  });

  final List<PlayMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final IconData icon;
  final String semanticLabel;
  final PlayIconButtonVariant variant;
  final double size;

  @override
  State<PlayMenuButton<T>> createState() => _PlayMenuButtonState<T>();
}

class _PlayMenuButtonState<T> extends State<PlayMenuButton<T>> {
  OverlayEntry? _entry;

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  void _remove() {
    _entry?.remove();
    _entry = null;
  }

  void _toggle() {
    if (_entry != null) {
      _remove();
      return;
    }
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    final RenderBox? overlayBox =
        overlay?.context.findRenderObject() as RenderBox?;
    if (overlay == null ||
        button == null ||
        overlayBox == null ||
        !button.hasSize ||
        !overlayBox.hasSize) {
      return;
    }
    final Rect anchor =
        button.localToGlobal(Offset.zero, ancestor: overlayBox) & button.size;

    _entry = OverlayEntry(
      builder: (BuildContext context) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GestureDetector(behavior: HitTestBehavior.opaque, onTap: _remove),
          CustomSingleChildLayout(
            delegate: _MenuLayout(anchor: anchor, margin: PlaySpace.sm),
            child: _Menu<T>(
              items: widget.items,
              onSelected: (T value) {
                _remove();
                widget.onSelected(value);
              },
            ),
          ),
        ],
      ),
    );
    overlay.insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    return PlayIconButton(
      icon: widget.icon,
      variant: widget.variant,
      size: widget.size,
      iconSize: widget.size * 0.5,
      semanticLabel: widget.semanticLabel,
      onPressed: _toggle,
    );
  }
}

/// Places the menu below the anchor, flipping above when needed and clamping it
/// inside the viewport so it can never run off screen.
class _MenuLayout extends SingleChildLayoutDelegate {
  const _MenuLayout({required this.anchor, required this.margin});

  final Rect anchor;
  final double margin;

  static const double _preferredWidth = 280;
  static const double _gap = 4;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final double maxWidth = math.max(
      120,
      math.min(_preferredWidth, constraints.maxWidth - margin * 2),
    );
    return BoxConstraints(
      maxWidth: maxWidth,
      maxHeight: math.max(0, constraints.maxHeight - margin * 2),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double dx = anchor.right - childSize.width;
    final double below = anchor.bottom + _gap;
    final double dy = below + childSize.height > size.height - margin
        ? anchor.top - _gap - childSize.height
        : below;
    final double maxX = math.max(margin, size.width - childSize.width - margin);
    final double maxY = math.max(
      margin,
      size.height - childSize.height - margin,
    );
    return Offset(dx.clamp(margin, maxX), dy.clamp(margin, maxY));
  }

  @override
  bool shouldRelayout(_MenuLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

class _Menu<T> extends StatelessWidget {
  const _Menu({required this.items, required this.onSelected});

  final List<PlayMenuItem<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return DefaultTextStyle(
      style: PlayType.bodyStrong.copyWith(color: colors.ink),
      child: PlaySurface(
        radius: PlayRadii.md,
        borderWidth: 1,
        shadow: PlayShadow.soft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final PlayMenuItem<T> item in items)
              PlayPressable(
                onTap: () => onSelected(item.value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PlaySpace.lg,
                    vertical: PlaySpace.md,
                  ),
                  child: Row(
                    children: <Widget>[
                      if (item.icon != null) ...<Widget>[
                        Icon(
                          item.icon,
                          size: 18,
                          color: colors.tone(item.tone).foreground,
                        ),
                        const SizedBox(width: PlaySpace.md),
                      ],
                      Expanded(
                        child: Text(
                          item.label,
                          style: PlayType.bodyStrong.copyWith(
                            color: colors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

@PlayPreview(name: 'PlayMenuButton', size: Size(360, 260))
Widget playMenuButtonPreview() {
  return PlayPreviewFrame(
    alignment: Alignment.topRight,
    child: PlayMenuButton<String>(
      onSelected: (String _) {},
      items: const <PlayMenuItem<String>>[
        PlayMenuItem<String>(
          value: 'remove',
          label: 'Remove Home',
          icon: PlayIcons.layers,
        ),
        PlayMenuItem<String>(
          value: 'edit',
          label: 'Edit',
          icon: PlayIcons.copy,
        ),
      ],
    ),
  );
}
