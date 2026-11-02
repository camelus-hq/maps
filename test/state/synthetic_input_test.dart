import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/state/commands/synthetic_input.dart';

/// Guards the `ui.*` synthetic-input primitives against the widget stack they
/// are built to drive.
void main() {
  testWidgets('tap activates a button at the given coordinates', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 100,
              child: ElevatedButton(
                onPressed: () => taps++,
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Offset centre = tester.getCenter(find.text('Go'));
    SyntheticInput.tap(centre.dx, centre.dy);
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('swipe drags a DraggableScrollableSheet to its expanded size', (
    WidgetTester tester,
  ) async {
    final DraggableScrollableController controller =
        DraggableScrollableController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DraggableScrollableSheet(
            controller: controller,
            initialChildSize: 0.2,
            minChildSize: 0.2,
            maxChildSize: 0.9,
            snap: true,
            snapSizes: const <double>[0.2, 0.9],
            builder: (BuildContext context, ScrollController scrollController) {
              return ListView.builder(
                controller: scrollController,
                itemCount: 50,
                itemBuilder: (BuildContext context, int index) =>
                    SizedBox(height: 40, child: Text('row $index')),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.size, closeTo(0.2, 0.01));

    final Size size = tester.view.physicalSize / tester.view.devicePixelRatio;
    SyntheticInput.swipe(
      fromX: size.width / 2,
      fromY: size.height - 20,
      toX: size.width / 2,
      toY: size.height * 0.2,
    );
    await tester.pumpAndSettle();

    expect(controller.size, greaterThan(0.5));
  });
}
