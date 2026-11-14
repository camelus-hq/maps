import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/features/common/error_text.dart';

void main() {
  test('offline failures get an explicit offline message and icon', () {
    final ({IconData icon, String text}) offline = errorPresentation(
      const OfflineException('Geocoding request failed'),
      fallback: 'Search failed',
    );
    expect(offline.icon, Icons.wifi_off);
    expect(offline.text, contains('offline'));
  });

  test('timeouts get their own message', () {
    final ({IconData icon, String text}) timeout = errorPresentation(
      const RequestTimeoutException('Geocoding request timed out'),
      fallback: 'Search failed',
    );
    expect(timeout.icon, Icons.timer_off_outlined);
    expect(timeout.text, 'Geocoding request timed out');
  });

  test('other errors fall back to the typed message, then the fallback', () {
    expect(
      errorPresentation(
        const ValidationException('Malformed response'),
        fallback: 'Search failed',
      ).text,
      'Malformed response',
    );
    expect(
      errorPresentation(null, fallback: 'Search failed').text,
      'Search failed',
    );
  });

  test('an unsupported feature gets its own message, not a raw error', () {
    final ({IconData icon, String text}) unsupported = errorPresentation(
      const UnsupportedException('No Mapbox category for "toilets"'),
      fallback: 'Search failed',
    );
    expect(unsupported.icon, Icons.search_off);
    expect(unsupported.text, contains("can't browse that category"));
    expect(unsupported.text, isNot(contains('No Mapbox category')));
  });
}
