import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/place_category.dart';
import 'package:openmaps/features/common/place_result_icon.dart';
import 'package:openmaps/features/map_home/widgets/category_chips.dart';

/// Guards the "one source of truth" rule for category iconography: the chips
/// under the search bar paint the same [placeResultIcon] glyph as the search
/// results, so there is no second icon table to drift.
void main() {
  testWidgets('category chips paint the shared place-result glyph', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: CategoryChips())),
      ),
    );
    await tester.pumpAndSettle();

    for (final PlaceCategory category in categoriesByIds(
      defaultPinnedCategoryIds,
    )) {
      expect(
        find.byIcon(placeResultIcon(category.id)),
        findsWidgets,
        reason: 'the "${category.id}" chip should use placeResultIcon',
      );
    }
  });
}
