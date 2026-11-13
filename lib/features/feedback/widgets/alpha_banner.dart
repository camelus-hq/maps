import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/app_update.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/update.dart';

/// The size of the corner the ribbon is drawn into. The diagonal band is the
/// same one Flutter's debug banner uses, so it looks familiar; this is only the
/// widget's box (clipped by the screen edge).
const double _bannerExtent = 96.0;

/// The ribbon's message: `alpha <version>`, or just `alpha` before the platform
/// version has loaded. Pure so it is unit-testable.
String alphaBannerLabel(AppVersion version) =>
    version.isKnown && version.versionName.isNotEmpty
    ? 'alpha ${version.versionName}'
    : 'alpha';

/// Overlays the tappable `alpha <version>` ribbon on top of [child].
///
/// Sits in `MaterialApp.router`'s `builder` (like Flutter's own debug banner and
/// `UpdatePromptHost`), so it floats above every route. The ribbon itself is the
/// only part that takes taps — the rest of the corner stays transparent, so the
/// map beneath is still interactive.
class AlphaBannerHost extends StatelessWidget {
  const AlphaBannerHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The app draws edge to edge, so the very corner is behind the status bar
    // (and its icon cluster would hide the start of the label). Anchor the
    // ribbon just below the status bar so `alpha <version>` stays readable and
    // the tap target never fights the system UI.
    final double topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        child,
        Positioned(top: topInset, right: 0, child: const AlphaBanner()),
      ],
    );
  }
}

/// The red corner ribbon reading `alpha <version>`. Tapping it dispatches
/// `feedback.open`, which captures the screen and opens the feedback form.
class AlphaBanner extends ConsumerWidget {
  const AlphaBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppVersion version =
        ref.watch(installedVersionProvider).value ?? AppVersion.unknown;
    final String message = alphaBannerLabel(version);
    return Semantics(
      button: true,
      label: 'Send alpha feedback',
      child: SizedBox(
        width: _bannerExtent,
        height: _bannerExtent,
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTap: () => unawaited(
            ref
                .read(commandRegistryProvider)
                .dispatch('feedback.open', const <String, Object?>{}),
          ),
          child: CustomPaint(
            painter: _RibbonPainter(
              message: message,
              textDirection: Directionality.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the diagonal ribbon exactly like Flutter's `Banner` (top-end) and makes
/// the whole top-right corner triangle tappable, so taps elsewhere fall through
/// to the app.
class _RibbonPainter extends CustomPainter {
  _RibbonPainter({required this.message, required this.textDirection})
    : _delegate = BannerPainter(
        message: message,
        textDirection: textDirection,
        location: BannerLocation.topEnd,
        layoutDirection: TextDirection.ltr,
        color: _color,
        textStyle: _textStyle,
      );

  final String message;
  final TextDirection textDirection;

  /// Flutter's painter (same geometry as the debug banner), reused so a repaint
  /// does not rebuild its text layout.
  final BannerPainter _delegate;

  /// Most of the ribbon is Flutter's debug-banner geometry (via [BannerPainter]);
  /// we only supply the text style and keep the tap triangle inside the corner.
  static const Color _color = Color(0xA0B71C1C);
  static const TextStyle _textStyle = TextStyle(
    color: Color(0xFFFFFFFF),
    fontSize: 9,
    fontWeight: FontWeight.w900,
    height: 1.0,
  );

  /// The tap target reaches this far (perpendicular) from the corner, just past
  /// the ribbon's inner edge — so the whole corner triangle is tappable without
  /// reaching a top-right AppBar action.
  static const double _tapReach = 68.0;

  @override
  void paint(Canvas canvas, Size size) => _delegate.paint(canvas, size);

  @override
  bool shouldRepaint(covariant _RibbonPainter oldDelegate) =>
      oldDelegate.message != message ||
      oldDelegate.textDirection != textDirection;

  @override
  bool hitTest(Offset position) {
    // The whole top-right corner triangle is the tap target — from the corner
    // out to the ribbon's inner edge — so the corner is easy to hit, not just
    // the thin diagonal band. (The hypotenuse sits just outside the band, so it
    // never reaches a top-right AppBar action.)
    if (position.dx > _bannerExtent || position.dy < 0) {
      return false;
    }
    final double fromCorner = (_bannerExtent - position.dx) + position.dy;
    return fromCorner <= _tapReach;
  }
}
