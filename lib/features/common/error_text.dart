import 'package:flutter/widgets.dart';

import '../../core/errors/app_exception.dart';
import '../design/play_icons.dart';

/// The user-facing line and icon for a failed request.
///
/// Offline failures get an explicit "you're offline" state (a distinct icon and
/// copy) so the user knows it's their connection, not the app; an unsupported
/// feature (e.g. a search provider with no category index for an amenity) gets
/// its own line rather than a silent substitute; everything else falls back to
/// the typed exception's own human-readable message.
///
/// Icons come from the play kit (Phosphor), never Material.
({String text, IconData icon}) errorPresentation(
  AppException? error, {
  required String fallback,
}) {
  if (error?.isOffline ?? false) {
    return (
      text: "You're offline. Check your connection and try again.",
      icon: PlayIcons.offline,
    );
  }
  if (error is UnsupportedException) {
    return (
      text:
          "This search provider can't browse that category. Pick another "
          'provider in Settings.',
      icon: PlayIcons.unsupported,
    );
  }
  if (error is RequestTimeoutException) {
    return (text: error.message, icon: PlayIcons.timeout);
  }
  return (text: error?.message ?? fallback, icon: PlayIcons.cloudOff);
}
