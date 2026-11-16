import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../play_icons.dart';
import '../play_previews.dart';
import 'play_icon_button.dart';
import 'play_surface.dart';

/// A rounded text field — the play replacement for Material's `TextField`.
///
/// Built on [EditableText] (the widgets-layer editor), so it needs no Material:
/// the pill surface, the leading slot, the hint overlay, the clear button and
/// the caret/selection colours are all ours.
class PlayTextField extends StatefulWidget {
  const PlayTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.leading,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.textInputAction,
    this.clearable = true,
    this.padding = const EdgeInsets.symmetric(
      horizontal: PlaySpace.lg,
      vertical: PlaySpace.md,
    ),
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final Widget? leading;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final TextInputAction? textInputAction;

  /// Shows a clear (✕) button once there is text.
  final bool clearable;
  final EdgeInsetsGeometry padding;

  @override
  State<PlayTextField> createState() => _PlayTextFieldState();
}

class _PlayTextFieldState extends State<PlayTextField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  late final bool _ownsController = widget.controller == null;
  late final bool _ownsFocus = widget.focusNode == null;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    if (_ownsFocus) {
      _focus.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final bool hasText = _controller.text.isNotEmpty;
    final String? hint = widget.hint;
    final Widget? leading = widget.leading;
    final Widget? trailing = widget.trailing;
    final TextInputAction? action = widget.textInputAction;

    return PlaySurface(
      radius: PlayRadii.pill,
      borderWidth: 1,
      shadow: PlayShadow.none,
      padding: widget.padding,
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            leading,
            const SizedBox(width: PlaySpace.sm),
          ],
          Expanded(
            child: Stack(
              children: <Widget>[
                if (hint != null && !hasText)
                  Text(
                    hint,
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
                  maxLines: 1,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.text,
                  textInputAction: action,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                ),
              ],
            ),
          ),
          if (widget.clearable && hasText) ...<Widget>[
            const SizedBox(width: PlaySpace.xs),
            PlayIconButton(
              icon: PlayIcons.close,
              variant: PlayIconButtonVariant.plain,
              size: 32,
              iconSize: 18,
              semanticLabel: 'Clear',
              onPressed: _clear,
            ),
          ],
          if (trailing != null) ...<Widget>[
            const SizedBox(width: PlaySpace.xs),
            trailing,
          ],
        ],
      ),
    );
  }
}

@PlayPreview(name: 'PlayTextField', size: Size(460, 220))
Widget playTextFieldPreview() {
  return PlayPreviewFrame(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const PlayTextField(hint: 'Search here'),
        const SizedBox(height: PlaySpace.lg),
        PlayTextField(
          hint: 'Filter places',
          leading: Builder(
            builder: (BuildContext context) => Icon(
              PlayIcons.search,
              size: 20,
              color: PlayColors.of(context).inkMuted,
            ),
          ),
        ),
      ],
    ),
  );
}
