import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/theme/play/play_colors.dart';
import '../../core/theme/play/play_tokens.dart';
import 'atoms/play_surface.dart';

/// Shows a short, non-Material toast at the bottom of the screen — our
/// replacement for `ScaffoldMessenger.showSnackBar` for brief feedback.
///
/// Inserted into the root [Overlay] (which the app's `MaterialApp` provides), it
/// animates in, holds for ~2s, then fades out and removes itself. It ignores
/// pointers, so it never swallows a tap, and it cancels its timer on dispose.
void showPlayToast(BuildContext context, String message) {
  final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    return;
  }
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext context) => _PlayToast(
      message: message,
      onClosed: () {
        if (entry.mounted) {
          entry.remove();
        }
      },
    ),
  );
  overlay.insert(entry);
}

class _PlayToast extends StatefulWidget {
  const _PlayToast({required this.message, required this.onClosed});

  final String message;
  final VoidCallback onClosed;

  @override
  State<_PlayToast> createState() => _PlayToastState();
}

class _PlayToastState extends State<_PlayToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(const Duration(milliseconds: 1900), _close);
  }

  Future<void> _close() async {
    if (!mounted) {
      return;
    }
    await _controller.reverse();
    widget.onClosed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final Animation<double> curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return Positioned.fill(
      child: IgnorePointer(
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(PlaySpace.xl),
              child: FadeTransition(
                opacity: _controller,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.4),
                    end: Offset.zero,
                  ).animate(curved),
                  child: PlaySurface(
                    tone: PlayTone.strong,
                    radius: PlayRadii.pill,
                    shadow: PlayShadow.soft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: PlaySpace.xl,
                      vertical: PlaySpace.md,
                    ),
                    child: Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: PlayType.bodyStrong.copyWith(
                        color: colors.onStrong,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
