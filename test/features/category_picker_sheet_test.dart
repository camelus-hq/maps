import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/features/map_home/widgets/category_picker_sheet.dart';
import 'package:openmaps/state/home.dart';
import 'package:openmaps/state/search.dart';
import 'package:openmaps/state/settings.dart';

void main() {
  Future<ProviderContainer> pumpSheet(WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: CategoryPickerSheet())),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('shows the categories grouped with a pin hint', (
    WidgetTester tester,
  ) async {
    await pumpSheet(tester);

    expect(find.text('Choose categories'), findsOneWidget);
    expect(find.textContaining('long press to pin'), findsOneWidget);
    expect(find.text('SUSTENANCE'), findsOneWidget);
    expect(find.text('Restaurants'), findsOneWidget);
    expect(find.text('Cafes'), findsOneWidget);
  });

  testWidgets('long press pins a chip to the row', (WidgetTester tester) async {
    final ProviderContainer container = await pumpSheet(tester);
    expect(
      container.read(settingsProvider).pinnedCategoryIds,
      isNot(contains('restaurant')),
    );

    await tester.longPress(find.text('Restaurants'));
    await tester.pumpAndSettle();

    expect(
      container.read(settingsProvider).pinnedCategoryIds,
      contains('restaurant'),
    );
    // Feedback confirms the pin.
    expect(find.textContaining('pinned'), findsWidgets);
    // The long press must not also run the browse (a stray tap).
    expect(container.read(searchControllerProvider).lastQuery, isNull);
    expect(container.read(selectedCategoryProvider), isNull);

    // Long pressing again unpins it.
    await tester.longPress(find.text('Restaurants'));
    await tester.pumpAndSettle();
    expect(
      container.read(settingsProvider).pinnedCategoryIds,
      isNot(contains('restaurant')),
    );
  });

  testWidgets('short press runs the category browse', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpSheet(tester);

    await tester.tap(find.text('Restaurants'));
    await tester.pumpAndSettle();

    expect(container.read(searchControllerProvider).lastQuery, 'Restaurants');
  });
}
