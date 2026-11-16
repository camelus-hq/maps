import 'package:flutter/widgets.dart';

import '../../core/theme/play/play_colors.dart';
import 'atoms/play_sheet.dart';

/// Shows a modal sheet built from the play kit — our replacement for
/// `showModalBottomSheet`.
///
/// It is a frosted-barrier [PopupRoute] that slides the sheet up from the
/// bottom, hugs its content by default (pass [heightFactor] to claim a fraction
/// of the screen), pads for the bottom system inset, and dismisses on a barrier
/// tap or a downward drag on the sheet's non-scrolling area.
Future<T?> showPlaySheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double? heightFactor,
  PlayTone tone = PlayTone.neutral,
  bool dismissible = true,
}) {
  return Navigator.of(context).push<T>(
    _PlaySheetRoute<T>(
      builder: builder,
      heightFactor: heightFactor,
      tone: tone,
      dismissible: dismissible,
    ),
  );
}

class _PlaySheetRoute<T> extends PopupRoute<T> {
  _PlaySheetRoute({
    required this.builder,
    required this.heightFactor,
    required this.tone,
    required this.dismissible,
  });

  final WidgetBuilder builder;
  final double? heightFactor;
  final PlayTone tone;
  final bool dismissible;

  @override
  Color? get barrierColor => dismissible ? const Color(0x66000000) : null;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final MediaQueryData media = MediaQuery.of(context);
    final double screenHeight = media.size.height;
    final double bottomInset = media.viewPadding.bottom;

    Widget sheet = PlaySheet(
      tone: tone,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const PlaySheetHandle(),
          Flexible(child: builder(context)),
          SizedBox(height: bottomInset),
        ],
      ),
    );

    final double? factor = heightFactor;
    if (factor != null) {
      sheet = SizedBox(height: screenHeight * factor, child: sheet);
    }

    final Widget positioned = Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
        child: sheet,
      ),
    );

    if (!dismissible) {
      return positioned;
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: (DragEndDetails details) {
        if ((details.primaryVelocity ?? 0) > 350) {
          Navigator.of(context).maybePop();
        }
      },
      child: positioned,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Animation<double> curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    );
  }
}
