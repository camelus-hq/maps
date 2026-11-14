import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/core/theme/app_theme.dart';
import 'package:openmaps/features/place_details/widgets/place_weekly_hours.dart';

/// The Overview tab's general opening hours: the whole week, today highlighted.
void main() {
  // A Tuesday in October.
  final DateTime tuesday = DateTime(2026, 10, 27, 12);

  Future<void> pump(WidgetTester tester, String? hours) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PlaceWeeklyHours(hours: hours, now: tuesday),
        ),
      ),
    );
  }

  testWidgets('lists every day of the week', (WidgetTester tester) async {
    await pump(tester, 'Mo-Fr 09:00-18:00; Sa 09:00-17:00; Su,PH 12:00-17:00');
    expect(find.text('Opening hours'), findsOneWidget);
    for (final String day in <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ]) {
      expect(find.text(day), findsOneWidget, reason: day);
    }
    expect(find.text('09:00-18:00'), findsNWidgets(5));
    expect(find.text('09:00-17:00'), findsOneWidget);
    expect(find.text('12:00-17:00'), findsOneWidget);
  });

  testWidgets('a closed day reads as "Closed"', (WidgetTester tester) async {
    await pump(tester, 'Mo-Fr 09:00-18:00; Sa,Su off');
    expect(find.text('Closed'), findsNWidgets(2));
  });

  testWidgets('24/7 collapses to one line', (WidgetTester tester) async {
    await pump(tester, '24/7');
    expect(find.text('Open 24 hours'), findsOneWidget);
    expect(find.text('Mon'), findsNothing);
  });

  testWidgets('renders nothing for an unknown tag', (
    WidgetTester tester,
  ) async {
    await pump(tester, 'by appointment');
    expect(find.text('Opening hours'), findsNothing);
  });
}
