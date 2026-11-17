import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../atoms/play_icon_button.dart';
import '../play_icons.dart';
import '../play_previews.dart';

/// A play page frame — our replacement for Material's `Scaffold`.
///
/// Paints the paper canvas, applies the safe-area insets, sets the play default
/// text style and lays an optional [PlayAppBar] above the content. It does not
/// need a `Material` ancestor.
class PlayScaffold extends StatelessWidget {
  const PlayScaffold({
    super.key,
    this.appBar,
    required this.child,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget? appBar;
  final Widget child;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final MediaQueryData media = MediaQuery.of(context);
    final Widget? bar = appBar;
    final double keyboard = resizeToAvoidBottomInset
        ? media.viewInsets.bottom
        : 0;
    return ColoredBox(
      color: colors.canvas,
      child: SafeArea(
        top: bar == null,
        bottom: keyboard <= 0,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: DefaultTextStyle(
            style: PlayType.body.copyWith(color: colors.ink),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ?bar,
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A play top bar for a [PlayScaffold]: back affordance, title (+ subtitle) and
/// trailing actions.
class PlayAppBar extends StatelessWidget {
  const PlayAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.showBack = true,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final double topInset = MediaQuery.viewPaddingOf(context).top;
    final NavigatorState? navigator = Navigator.maybeOf(context);
    final bool canPop = showBack && (navigator?.canPop() ?? false);
    final String? heading = title;
    final String? sub = subtitle;

    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PlaySpace.sm,
          PlaySpace.sm,
          PlaySpace.md,
          PlaySpace.md,
        ),
        child: Row(
          children: <Widget>[
            if (canPop)
              PlayIconButton(
                icon: PlayIcons.back,
                variant: PlayIconButtonVariant.plain,
                size: 44,
                semanticLabel: 'Back',
                onPressed: () => navigator?.maybePop(),
              )
            else
              const SizedBox(width: PlaySpace.sm),
            const SizedBox(width: PlaySpace.xs),
            if (heading != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      heading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PlayType.title.copyWith(color: colors.ink),
                    ),
                    if (sub != null)
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PlayType.caption.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

@PlayPreview(name: 'PlayScaffold', size: Size(420, 420))
Widget playScaffoldPreview() {
  return PlayScaffold(
    appBar: PlayAppBar(
      title: 'Saved',
      subtitle: '3 places',
      actions: <Widget>[
        PlayIconButton(
          icon: PlayIcons.more,
          variant: PlayIconButtonVariant.plain,
          size: 44,
          semanticLabel: 'More',
          onPressed: () {},
        ),
      ],
    ),
    child: Builder(
      builder: (BuildContext context) => Center(
        child: Text(
          'page content',
          style: PlayType.body.copyWith(color: PlayColors.of(context).inkMuted),
        ),
      ),
    ),
  );
}
