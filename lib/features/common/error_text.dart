import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';

/// The user-facing line and icon for a failed request.
///
/// Offline failures get an explicit "you're offline" state (a distinct icon and
/// copy) so the user knows it's their connection, not the app; an unsupported
/// feature (e.g. a search provider with no category index for an amenity) gets
/// its own line rather than a silent substitute; everything else falls back to
/// the typed exception's own human-readable message.
({String text, IconData icon}) errorPresentation(
  AppException? error, {
  required String fallback,
}) {
  if (error?.isOffline ?? false) {
    return (
      text: "You're offline. Check your connection and try again.",
      icon: Icons.wifi_off,
    );
  }
  if (error is UnsupportedException) {
    return (
      text:
          "This search provider can't browse that category. Pick another "
          'provider in Settings.',
      icon: Icons.search_off,
    );
  }
  if (error is RequestTimeoutException) {
    return (text: error.message, icon: Icons.timer_off_outlined);
  }
  return (text: error?.message ?? fallback, icon: Icons.cloud_off_outlined);
}
