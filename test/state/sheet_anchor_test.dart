import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/state/sheet_anchor.dart';

void main() {
  test('hidesChrome only above the threshold, with a small tolerance', () {
    expect(const SheetAnchor(topInset: 10, fraction: 0.2).hidesChrome, isFalse);
    // A sheet parked at exactly the threshold (the place sheet's half snap)
    // stays visible.
    expect(
      const SheetAnchor(
        topInset: 10,
        fraction: kSheetChromeFadeThreshold,
      ).hidesChrome,
      isFalse,
    );
    expect(
      const SheetAnchor(topInset: 10, fraction: 0.504).hidesChrome,
      isFalse,
    );
    expect(const SheetAnchor(topInset: 10, fraction: 0.51).hidesChrome, isTrue);
    expect(const SheetAnchor(topInset: 10, fraction: 0.8).hidesChrome, isTrue);
  });

  test('report records an anchor and clear resets it', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final SheetAnchorController controller = container.read(
      sheetAnchorProvider.notifier,
    );

    expect(container.read(sheetAnchorProvider), isNull);

    const SheetAnchor anchor = SheetAnchor(topInset: 120, fraction: 0.2);
    controller.report(anchor, generation: 1);
    expect(container.read(sheetAnchorProvider), anchor);

    controller.clear();
    expect(container.read(sheetAnchorProvider), isNull);
  });

  test('report ignores a superseded sheet generation', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final SheetAnchorController controller = container.read(
      sheetAnchorProvider.notifier,
    );

    const SheetAnchor newer = SheetAnchor(topInset: 120, fraction: 0.2);
    const SheetAnchor older = SheetAnchor(topInset: 400, fraction: 0.6);

    // The new sheet reports first, then the sheet fading out reports stale
    // geometry that must not clobber it.
    controller.report(newer, generation: 7);
    controller.report(older, generation: 6);
    expect(container.read(sheetAnchorProvider), newer);

    // The same generation may keep reporting (a drag).
    const SheetAnchor dragged = SheetAnchor(topInset: 260, fraction: 0.35);
    controller.report(dragged, generation: 7);
    expect(container.read(sheetAnchorProvider), dragged);

    // A later generation wins again.
    const SheetAnchor newest = SheetAnchor(topInset: 50, fraction: 0.1);
    controller.report(newest, generation: 8);
    expect(container.read(sheetAnchorProvider), newest);
  });

  test('report ignores degenerate anchors', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final SheetAnchorController controller = container.read(
      sheetAnchorProvider.notifier,
    );

    controller.report(
      const SheetAnchor(topInset: double.nan, fraction: 0.2),
      generation: 1,
    );
    controller.report(
      const SheetAnchor(topInset: -1, fraction: 0.2),
      generation: 1,
    );
    controller.report(
      const SheetAnchor(topInset: 10, fraction: -0.1),
      generation: 1,
    );
    controller.report(
      const SheetAnchor(topInset: 10, fraction: double.infinity),
      generation: 1,
    );

    expect(container.read(sheetAnchorProvider), isNull);
  });
}
