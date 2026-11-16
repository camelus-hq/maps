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
/// the surface, the leading slot, the hint overlay, the clear button and the
/// caret/selection colours are all ours. Single-line fields are pill-shaped;
/// multi-line ones use a rounded rectangle with the content aligned to the top.
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
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.clearable = true,
    this.padding,
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
  final TextCapitalization textCapitalization;
  final int maxLines;
  final int? minLines;
  final int? maxLength;

  /// Shows a clear (✕) button once there is text.
  final bool clearable;
  final EdgeInsetsGeometry? padding;

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
    final bool multiline = widget.maxLines > 1;
    final bool hasText = _controller.text.isNotEmpty;
    final String? hint = widget.hint;
    final Widget? leading = widget.leading;
    final Widget? trailing = widget.trailing;
    final int? maxLength = widget.maxLength;

    final Widget field = PlaySurface(
      radius: multiline ? PlayRadii.md : PlayRadii.pill,
      borderWidth: 1,
      shadow: PlayShadow.none,
      padding:
          widget.padding ??
          EdgeInsets.symmetric(
            horizontal: PlaySpace.lg,
            vertical: multiline ? PlaySpace.md : PlaySpace.md,
          ),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: <Widget>[
          if (leading != null) ...<Widget>[
            multiline
                ? Padding(
                    padding: const EdgeInsets.only(top: PlaySpace.xs),
                    child: leading,
                  )
                : leading,
            const SizedBox(width: PlaySpace.sm),
          ],
          Expanded(
            child: Stack(
              children: <Widget>[
                if (hint != null && !hasText)
                  Text(
                    hint,
                    maxLines: multiline ? widget.maxLines : 1,
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
                  maxLines: widget.maxLines,
                  minLines: widget.minLines,
                  autofocus: widget.autofocus,
                  keyboardType: multiline
                      ? TextInputType.multiline
                      : TextInputType.text,
                  textInputAction: widget.textInputAction,
                  textCapitalization: widget.textCapitalization,
                  inputFormatters: maxLength == null
                      ? null
                      : <TextInputFormatter>[
                          LengthLimitingTextInputFormatter(maxLength),
                        ],
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                ),
              ],
            ),
          ),
          if (widget.clearable && hasText && !multiline) ...<Widget>[
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

    if (maxLength == null) {
      return field;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        field,
        const SizedBox(height: PlaySpace.xs),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_controller.text.length}/$maxLength',
            style: PlayType.caption.copyWith(color: colors.inkFaint),
          ),
        ),
      ],
    );
  }
}

@PlayPreview(name: 'PlayTextField', size: Size(460, 360))
Widget playTextFieldPreview() {
  return PlayPreviewFrame(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const PlayTextField(hint: 'Search here'),
        const SizedBox(height: PlaySpace.lg),
        PlayTextField(
          hint: 'What happened?',
          maxLines: 4,
          minLines: 3,
          maxLength: 200,
          leading: Builder(
            builder: (BuildContext context) => Icon(
              PlayIcons.review,
              size: 20,
              color: PlayColors.of(context).inkMuted,
            ),
          ),
        ),
      ],
    ),
  );
}
