import 'package:material_ui/material_ui.dart';

/// Original palette. The map styling is our own — nothing here is sampled from
/// Google Maps (AGENTS.md §Assets).
abstract final class AppColors {
  /// Brand seed used to derive the Material colour schemes.
  static const Color seed = Color(0xFF116B5B);

  /// Neutral backdrop behind the map surface until it reports ready.
  static const Color mapPlaceholder = Color(0xFFDDE3E0);
  static const Color mapPlaceholderDark = Color(0xFF1B2422);

  /// Opening-hours status (our own traffic-light colours, readable on the light
  /// and dark surfaces; not sampled from any product).
  static const Color statusOpen = Color(0xFF2E9E5B);
  static const Color statusSoon = Color(0xFFDD8500);
  static const Color statusClosed = Color(0xFFD14B45);
}
