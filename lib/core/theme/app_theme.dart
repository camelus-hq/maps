import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'play/play_colors.dart';

/// The app's Material `ThemeData`.
///
/// The Play design system (`lib/features/design/`) paints the whole UI with its
/// own tokens, so this theme only reaches the framework and third-party widgets
/// that still ask Flutter for a `Theme` (the router's overlays, text-selection
/// handles, and the `ndk_flutter` login widget). It is seeded from our own
/// colours so those widgets stay in step with the Play look.
abstract final class AppTheme {
  static ThemeData light() => _base(PlayColors.light);

  static ThemeData dark() => _base(PlayColors.dark);

  static ThemeData _base(PlayColors colors) {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.seed,
          brightness: colors.brightness,
        ).copyWith(
          primary: colors.primary,
          onPrimary: colors.onPrimary,
          primaryContainer: colors.primarySoft,
          onPrimaryContainer: colors.onPrimarySoft,
          secondary: colors.teal,
          onSecondary: colors.onTeal,
          surface: colors.canvas,
          onSurface: colors.ink,
          surfaceContainerHighest: colors.surfaceSunken,
          onSurfaceVariant: colors.inkMuted,
          outline: colors.line,
          outlineVariant: colors.line,
          error: colors.coral,
        );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.canvas,
    );
  }
}
