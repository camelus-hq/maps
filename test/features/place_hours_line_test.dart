import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/core/theme/app_colors.dart';
import 'package:openmaps/core/theme/app_theme.dart';
import 'package:openmaps/features/place_details/widgets/place_hours_line.dart';

/// The place sheet's hours line: the four open/soon/closed states in green,
/// orange and red, plus the raw tag when the value is unreadable.
void main() {
  Future<void> pump(WidgetTester tester, String? hours, DateTime now) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PlaceHoursLine(hours: hours, now: now),
        ),
      ),
    );
  }

  DateTime monday(int hour, [int minute = 0]) =>
      DateTime(2026, 10, 26, hour, minute);

  Color dotColor(WidgetTester tester) {
    final Container dot = tester.widget<Container>(
      find.descendant(
        of: find.byType(PlaceHoursLine),
        matching: find.byWidgetPredicate(
          (Widget w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      ),
    );
    return (dot.decoration! as BoxDecoration).color!;
  }

  testWidgets('open now is green with the closing time', (
    WidgetTester tester,
  ) async {
    await pump(tester, 'Mo-Fr 09:00-18:00', monday(12));
    expect(find.text('Open now'), findsOneWidget);
    expect(find.text('Closes 18:00'), findsOneWidget);
    expect(dotColor(tester), AppColors.statusOpen);
  });

  testWidgets('closing soon is orange', (WidgetTester tester) async {
    await pump(tester, 'Mo-Fr 09:00-18:00', monday(17, 30));
    expect(find.text('Closing soon'), findsOneWidget);
    expect(find.text('Closes 18:00'), findsOneWidget);
    expect(dotColor(tester), AppColors.statusSoon);
  });

  testWidgets('opening soon is orange', (WidgetTester tester) async {
    await pump(tester, 'Mo-Fr 09:00-18:00', monday(8, 30));
    expect(find.text('Opening soon'), findsOneWidget);
    expect(find.text('Opens 09:00'), findsOneWidget);
    expect(dotColor(tester), AppColors.statusSoon);
  });

  testWidgets('closed now is red', (WidgetTester tester) async {
    await pump(tester, 'Mo-Fr 09:00-18:00', monday(20));
    expect(find.text('Closed now'), findsOneWidget);
    expect(dotColor(tester), AppColors.statusClosed);
  });

  testWidgets('24/7 reads as open with no change time', (
    WidgetTester tester,
  ) async {
    await pump(tester, '24/7', monday(3));
    expect(find.text('Open now'), findsOneWidget);
    expect(find.textContaining('Closes'), findsNothing);
  });

  testWidgets('an unreadable tag is shown verbatim', (
    WidgetTester tester,
  ) async {
    await pump(tester, 'by appointment', monday(12));
    expect(find.text('by appointment'), findsOneWidget);
    expect(find.text('Open now'), findsNothing);
  });

  testWidgets('no hours reads as "Hours not listed"', (
    WidgetTester tester,
  ) async {
    await pump(tester, null, monday(12));
    expect(find.text('Hours not listed'), findsOneWidget);
  });
}
