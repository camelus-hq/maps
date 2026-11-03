import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The sheet height fraction (of the screen) at which the floating map chrome —
/// the action buttons and the data attribution — fades out.
///
/// Up to and including this fraction (a 0.5 sheet still shows them) the chrome
/// sits just above the sheet; only above it does the sheet crowd the chrome, so
/// the chrome fades away instead.
const double kSheetChromeFadeThreshold = 0.5;

/// Tolerance so a sheet parked at exactly [kSheetChromeFadeThreshold] — e.g. the
/// place sheet's half-height snap — is not hidden by floating-point error in the
/// measured fraction.
const double _kSheetChromeFadeTolerance = 0.005;

/// Where the currently visible bottom sheet sits, in screen coordinates.
///
/// [topInset] is the distance in logical pixels from the bottom of the screen
/// to the sheet's top edge — the anchor the floating chrome is attached to.
/// [fraction] is the sheet's height as a fraction of the screen height, used to
/// decide when the chrome fades out.
class SheetAnchor {
  const SheetAnchor({required this.topInset, required this.fraction});

  /// A sheet occupying nothing at the bottom of the screen.
  static const SheetAnchor none = SheetAnchor(topInset: 0, fraction: 0);

  /// Distance from the screen bottom to the sheet's top edge, in logical px.
  final double topInset;

  /// The sheet height as a fraction of the screen height (0..1).
  final double fraction;

  /// Whether the sheet is tall enough that the floating chrome should hide.
  bool get hidesChrome =>
      fraction > kSheetChromeFadeThreshold + _kSheetChromeFadeTolerance;

  @override
  bool operator ==(Object other) =>
      other is SheetAnchor &&
      other.topInset == topInset &&
      other.fraction == fraction;

  @override
  int get hashCode => Object.hash(topInset, fraction);

  @override
  String toString() => 'SheetAnchor(topInset: $topInset, fraction: $fraction)';
}

/// Holds the visible sheet's geometry so the map controls and the attribution
/// can attach to it and fade out when it grows past
/// [kSheetChromeFadeThreshold].
///
/// Reported by [MapSheet] whenever the active sheet's size changes. `null`
/// means no sheet is currently measured (e.g. during guidance), so the chrome
/// stays hidden. Reports carry a generation so a sheet that is fading out under
/// an [AnimatedSwitcher] while a new one fades in cannot overwrite the new
/// sheet's geometry (see [report]).
class SheetAnchorController extends Notifier<SheetAnchor?> {
  int _generation = 0;

  @override
  SheetAnchor? build() => null;

  /// Records the latest measured anchor.
  ///
  /// [generation] identifies the [MapSheet] that measured it; a report from a
  /// generation older than the last accepted one is ignored, so the sheet
  /// animating out does not clobber the sheet animating in. Degenerate values
  /// and no-op updates are dropped so a drag does not rebuild the chrome
  /// needlessly.
  void report(SheetAnchor anchor, {required int generation}) {
    if (!anchor.topInset.isFinite ||
        !anchor.fraction.isFinite ||
        anchor.topInset < 0 ||
        anchor.fraction < 0) {
      return;
    }
    if (generation < _generation) {
      return;
    }
    _generation = generation;
    if (state == anchor) {
      return;
    }
    state = anchor;
  }

  /// Clears the anchor (the sheet is gone).
  void clear() {
    if (state != null) {
      state = null;
    }
  }
}

final NotifierProvider<SheetAnchorController, SheetAnchor?>
sheetAnchorProvider = NotifierProvider<SheetAnchorController, SheetAnchor?>(
  SheetAnchorController.new,
);
