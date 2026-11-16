import 'package:flutter/widget_previews.dart';
import 'package:flutter/widgets.dart';

import '../../core/theme/play/play_colors.dart';
import '../../core/theme/play/play_tokens.dart';

/// Renders a preview function in **both** Play themes, as two side-by-side
/// entries in the widget previewer ("… · light" and "… · dark").
///
/// This is the annotation every play atom/component preview uses, so a design
/// change can be checked in light and dark without toggling the previewer.
///
/// It is a [MultiPreview]: applying it is exactly equivalent to writing the two
/// `@Preview(brightness: …)` annotations by hand.
final class PlayPreview extends MultiPreview {
  const PlayPreview({this.name, this.size, this.group = 'Play design'});

  final String? name;
  final Size? size;
  final String group;

  @override
  List<Preview> get previews => <Preview>[
    Preview(
      group: group,
      name: name == null ? 'Light' : '$name · light',
      size: size,
      brightness: Brightness.light,
      theme: playPreviewTheme,
    ),
    Preview(
      group: group,
      name: name == null ? 'Dark' : '$name · dark',
      size: size,
      brightness: Brightness.dark,
      theme: playPreviewTheme,
    ),
  ];
}

/// The Play background/text shell applied to every previewed widget.
///
/// Must be a top-level function: the [Preview.theme] callback has to be a
/// static, public reference.
PreviewThemeData playPreviewTheme() => const _PlayPreviewTheme();

final class _PlayPreviewTheme extends PreviewThemeData {
  const _PlayPreviewTheme();

  @override
  Widget apply(BuildContext context, Widget child) {
    final PlayColors colors =
        MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark
        ? PlayColors.dark
        : PlayColors.light;
    return PlayTheme(
      colors: colors,
      child: ColoredBox(
        color: colors.canvas,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DefaultTextStyle(
            style: PlayType.body.copyWith(color: colors.ink),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Consistent padding and centring for a preview body.
class PlayPreviewFrame extends StatelessWidget {
  const PlayPreviewFrame({
    super.key,
    required this.child,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(padding: const EdgeInsets.all(PlaySpace.xl), child: child),
    );
  }
}
