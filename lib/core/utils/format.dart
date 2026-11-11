/// Pure-Dart formatting helpers shared by the route/navigation UI.
library;

/// Distance in metres → "850 m" / "5.4 km" (metric) or "0.5 mi" (imperial).
///
/// Pass [precise] for the active-travel modes (walking/cycling), where the
/// readout changes every few metres: above a kilometre it keeps two decimals
/// (10 m steps) instead of one (100 m steps), so the number visibly moves as
/// you go.
String formatDistance(
  double meters, {
  bool imperial = false,
  bool precise = false,
}) {
  if (imperial) {
    final double miles = meters / 1609.344;
    if (miles < 0.19) {
      return '${(meters * 3.28084).round()} ft';
    }
    return '${miles.toStringAsFixed(precise ? 2 : 1)} mi';
  }
  return meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(precise ? 2 : 1)} km';
}

/// A duration → "12 min" / "1 h 5 min".
String formatDuration(Duration duration) {
  final int minutes = duration.inMinutes;
  if (minutes < 60) {
    return '$minutes min';
  }
  final int hours = duration.inHours;
  final int rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}

/// A 24-hour clock label, e.g. "14:32" (used where no localisation is handy).
String formatClockTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// A short, relative age label: "just now", "5 min ago", "3 h ago",
/// "2 days ago", "3 weeks ago", or the date for anything older than a year.
String formatTimeAgo(DateTime time, {DateTime? now}) {
  final DateTime reference = (now ?? DateTime.now()).toUtc();
  final DateTime utc = time.toUtc();
  Duration diff = reference.difference(utc);
  if (diff.isNegative) {
    diff = Duration.zero;
  }
  final int minutes = diff.inMinutes;
  if (minutes < 1) {
    return 'just now';
  }
  if (minutes < 60) {
    return '$minutes min ago';
  }
  final int hours = diff.inHours;
  if (hours < 24) {
    return '$hours h ago';
  }
  final int days = diff.inDays;
  if (days < 7) {
    return days == 1 ? '1 day ago' : '$days days ago';
  }
  if (days < 30) {
    final int weeks = days ~/ 7;
    return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
  }
  if (days < 365) {
    final int months = days ~/ 30;
    return months <= 1 ? '1 month ago' : '$months months ago';
  }
  final int years = days ~/ 365;
  return years == 1 ? '1 year ago' : '$years years ago';
}
