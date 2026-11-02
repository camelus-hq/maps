import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/utils/format.dart';

void main() {
  test('formatDistance switches between metric and imperial', () {
    expect(formatDistance(850), '850 m');
    expect(formatDistance(5400), '5.4 km');
    expect(formatDistance(100, imperial: true), '328 ft');
    expect(formatDistance(5000, imperial: true), '3.1 mi');
  });

  test('formatDuration compacts hours', () {
    expect(formatDuration(const Duration(minutes: 12)), '12 min');
    expect(formatDuration(const Duration(minutes: 65)), '1 h 5 min');
    expect(formatDuration(const Duration(minutes: 120)), '2 h');
  });

  test('formatClockTime is zero-padded 24-hour', () {
    expect(formatClockTime(DateTime(2026, 1, 1, 9, 5)), '09:05');
    expect(formatClockTime(DateTime(2026, 1, 1, 14, 32)), '14:32');
  });

  test('formatTimeAgo picks a readable bucket', () {
    final DateTime now = DateTime.utc(2026, 6, 1, 12);
    String ago(Duration d) => formatTimeAgo(now.subtract(d), now: now);
    expect(ago(const Duration(seconds: 20)), 'just now');
    expect(ago(const Duration(minutes: 5)), '5 min ago');
    expect(ago(const Duration(hours: 3)), '3 h ago');
    expect(ago(const Duration(days: 1)), '1 day ago');
    expect(ago(const Duration(days: 2, hours: 3)), '2 days ago');
    expect(ago(const Duration(days: 10)), '1 week ago');
    expect(ago(const Duration(days: 60)), '2 months ago');
    expect(ago(const Duration(days: 400)), '1 year ago');
    // A clock skewed into the future never reads as negative.
    expect(
      formatTimeAgo(now.add(const Duration(hours: 1)), now: now),
      'just now',
    );
  });
}
