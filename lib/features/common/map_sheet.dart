import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../state/sheet_anchor.dart';

/// A [DraggableScrollableSheet] that reports its geometry to
/// [sheetAnchorProvider].
///
/// The floating map chrome (the action buttons and the data attribution) is
/// attached to whatever sheet is currently visible. A
/// [DraggableScrollableController] gives the sheet's height in pixels — a plain
/// [DraggableScrollableNotification] is only dispatched once a drag starts, so
/// it cannot anchor the chrome on the resting sheet — and the sheet's own
/// render box gives the region it sits in (the whole screen, or the area above
/// the bottom navigation bar on the home shell).
///
/// Every sheet on the map home goes through this wrapper. The map-home
/// [AnimatedSwitcher] briefly keeps the old sheet mounted while the new one
/// fades in, so each instance carries a monotonic generation and the controller
/// ignores stale reports (see [SheetAnchorController.report]).
class MapSheet extends ConsumerStatefulWidget {
  const MapSheet({
    super.key,
    required this.initialChildSize,
    required this.minChildSize,
    required this.maxChildSize,
    required this.builder,
    this.snap = true,
    this.snapSizes,
  });

  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final Widget Function(BuildContext context, ScrollController scrollController)
  builder;
  final bool snap;
  final List<double>? snapSizes;

  @override
  ConsumerState<MapSheet> createState() => _MapSheetState();
}

class _MapSheetState extends ConsumerState<MapSheet> {
  /// Global, monotonic id for this sheet instance, so a sheet fading out under
  /// the map-home [AnimatedSwitcher] cannot overwrite the one fading in.
  static int _nextGeneration = 0;

  final int _generation = ++_nextGeneration;
  final DraggableScrollableController _controller =
      DraggableScrollableController();
  bool _scheduled = false;
  int _startupRetries = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSheetChanged);
    _scheduleReport();
  }

  @override
  void dispose() {
    _controller.removeListener(_onSheetChanged);
    _controller.dispose();
    super.dispose();
  }

  /// A geometry change from the controller.
  ///
  /// Controller updates arrive from the gesture and animation phases, before
  /// the frame builds, so reporting synchronously lets the chrome (rebuilt in
  /// the same build phase) move with the sheet — deferring to a post-frame
  /// callback is a visible one-frame lag while dragging. Only during
  /// build/layout, where marking widgets dirty is illegal, do we wait for the
  /// frame to end.
  void _onSheetChanged() {
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      _scheduleReport();
    } else {
      _report();
    }
  }

  void _scheduleReport() {
    if (_scheduled) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) {
        _report();
      }
    });
  }

  void _report() {
    final double screenHeight = MediaQuery.sizeOf(context).height;
    // The controller attaches while the sheet's scroll view lays out; retry a
    // few frames on the first pass so the resting sheet is anchored without a
    // gesture.
    if (!_controller.isAttached) {
      if (_startupRetries < 5) {
        _startupRetries++;
        _scheduleReport();
      }
      return;
    }
    if (screenHeight <= 0) {
      return;
    }
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.attached || !object.hasSize) {
      return;
    }
    final double pixels = _controller.pixels;
    final double regionBottom = object
        .localToGlobal(Offset(0, object.size.height))
        .dy;
    final double visibleTop = regionBottom - pixels;
    ref
        .read(sheetAnchorProvider.notifier)
        .report(
          SheetAnchor(
            topInset: (screenHeight - visibleTop).clamp(0.0, screenHeight),
            fraction: (pixels / screenHeight).clamp(0.0, 1.0),
          ),
          generation: _generation,
        );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: widget.initialChildSize,
      minChildSize: widget.minChildSize,
      maxChildSize: widget.maxChildSize,
      snap: widget.snap,
      snapSizes: widget.snapSizes,
      builder: widget.builder,
    );
  }
}
