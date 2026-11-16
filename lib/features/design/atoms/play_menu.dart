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
/// The overlay is positioned with [CompositedTransformTarget]/[Follower] (widgets
/// layer), so no Material menu is involved; a tap outside dismisses it.
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
  final LayerLink _link = LayerLink();
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
    if (overlay == null) {
      return;
    }
    _entry = OverlayEntry(
      builder: (BuildContext context) => Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _remove,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, PlaySpace.xs),
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
    return CompositedTransformTarget(
      link: _link,
      child: PlayIconButton(
        icon: widget.icon,
        variant: widget.variant,
        size: widget.size,
        iconSize: widget.size * 0.5,
        semanticLabel: widget.semanticLabel,
        onPressed: _toggle,
      ),
    );
  }
}

class _Menu<T> extends StatelessWidget {
  const _Menu({required this.items, required this.onSelected});

  final List<PlayMenuItem<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
      child: DefaultTextStyle(
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
