import 'package:flutter/widgets.dart';

/// The named colour tones the Play design system paints with.
///
/// A tone is a (background, foreground) pair so a surface, a button or a tag
/// can be dropped on any backdrop and stay readable. Unlike Material's role
/// colours there is no automatic elevation tinting: a tone is exactly the
/// colour you picked.
enum PlayTone {
  /// Plain card on the page background.
  neutral,

  /// Recessed area (search wells, input strips).
  sunken,

  /// High-contrast inverted block (the reference's black card).
  strong,

  /// The brand blue, full saturation.
  primary,

  /// A soft blue wash of the brand colour.
  soft,

  mint,
  pink,
  lemon,
  sky,
  coral,
  teal,
}

/// Swatches for a surface elevation treatment.
///
/// `soft` is a diffuse drop shadow for floating cards; `pop` is a hard offset
/// "sticker" shadow that reads as a deliberate, non-Material signature.
enum PlayShadow {
  none,
  soft,
  pop;

  /// Resolves the box shadows for this treatment against [colors].
  List<BoxShadow> resolve(PlayColors colors) => switch (this) {
    PlayShadow.none => const <BoxShadow>[],
    PlayShadow.soft => <BoxShadow>[
      BoxShadow(
        color: colors.shadowSoft,
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
    PlayShadow.pop => <BoxShadow>[
      BoxShadow(color: colors.ink, offset: const Offset(0, 3)),
    ],
  };
}

/// A resolved (background, foreground, optional border) triple for a [PlayTone].
@immutable
class PlayToneColors {
  const PlayToneColors({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final Color? border;
}

/// The Play palette: one instance per brightness.
///
/// This is *our own* colour system, not a Material scheme — there is no
/// `fromSeed` derivation and no tonal palette. Both [light] and [dark] are
/// authored by hand so every tone stays legible in both modes.
@immutable
class PlayColors {
  const PlayColors({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.surfaceSunken,
    required this.line,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.onPrimarySoft,
    required this.mint,
    required this.onMint,
    required this.pink,
    required this.onPink,
    required this.lemon,
    required this.onLemon,
    required this.sky,
    required this.onSky,
    required this.coral,
    required this.onCoral,
    required this.teal,
    required this.onTeal,
    required this.strong,
    required this.onStrong,
    required this.shadowSoft,
  });

  final Brightness brightness;

  /// Page background behind everything (the "paper").
  final Color canvas;

  /// Default card / sheet fill.
  final Color surface;

  /// Recessed fill a shade darker than [canvas].
  final Color surfaceSunken;

  /// Hairline divider / outline colour.
  final Color line;

  /// Primary text.
  final Color ink;

  /// Secondary text.
  final Color inkMuted;

  /// Tertiary text, disabled glyphs.
  final Color inkFaint;

  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color onPrimarySoft;

  final Color mint;
  final Color onMint;
  final Color pink;
  final Color onPink;
  final Color lemon;
  final Color onLemon;
  final Color sky;
  final Color onSky;
  final Color coral;
  final Color onCoral;

  /// Brand accent carried over from the existing app teal.
  final Color teal;
  final Color onTeal;

  /// Inverted high-contrast block: dark in light mode, light in dark mode.
  final Color strong;
  final Color onStrong;

  /// Colour of the diffuse [PlayShadow.soft] shadow.
  final Color shadowSoft;

  /// Resolves [tone] against this palette.
  PlayToneColors tone(PlayTone tone) => switch (tone) {
    PlayTone.neutral => PlayToneColors(
      background: surface,
      foreground: ink,
      border: line,
    ),
    PlayTone.sunken => PlayToneColors(
      background: surfaceSunken,
      foreground: ink,
      border: line,
    ),
    PlayTone.strong => PlayToneColors(background: strong, foreground: onStrong),
    PlayTone.primary => PlayToneColors(
      background: primary,
      foreground: onPrimary,
    ),
    PlayTone.soft => PlayToneColors(
      background: primarySoft,
      foreground: onPrimarySoft,
    ),
    PlayTone.mint => PlayToneColors(background: mint, foreground: onMint),
    PlayTone.pink => PlayToneColors(background: pink, foreground: onPink),
    PlayTone.lemon => PlayToneColors(background: lemon, foreground: onLemon),
    PlayTone.sky => PlayToneColors(background: sky, foreground: onSky),
    PlayTone.coral => PlayToneColors(background: coral, foreground: onCoral),
    PlayTone.teal => PlayToneColors(background: teal, foreground: onTeal),
  };

  /// The resolved palette for the current context.
  ///
  /// Reads [PlayTheme] when one is in scope (so a subtree can be pinned to a
  /// brightness), otherwise follows the platform brightness — which is exactly
  /// what the widget previewer's light/dark toggle drives.
  static PlayColors of(BuildContext context) {
    final PlayColors? themed = PlayTheme.maybeOf(context);
    if (themed != null) {
      return themed;
    }
    return MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark
        ? dark
        : light;
  }

  static const PlayColors light = PlayColors(
    brightness: Brightness.light,
    canvas: Color(0xFFF6F2EA),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEDE8DC),
    line: Color(0xFFE6DFD1),
    ink: Color(0xFF212A38),
    inkMuted: Color(0xFF5C6675),
    inkFaint: Color(0xFF9AA2AF),
    primary: Color(0xFF2C4A73),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFDCE3FB),
    onPrimarySoft: Color(0xFF2A3B60),
    mint: Color(0xFFD9F0DF),
    onMint: Color(0xFF1E4D33),
    pink: Color(0xFFFBE0EC),
    onPink: Color(0xFF6A2545),
    lemon: Color(0xFFFBE9A8),
    onLemon: Color(0xFF5A4A12),
    sky: Color(0xFFDCE9FB),
    onSky: Color(0xFF26406B),
    coral: Color(0xFFE8556F),
    onCoral: Color(0xFFFFFFFF),
    teal: Color(0xFF1E6B52),
    onTeal: Color(0xFFFFFFFF),
    strong: Color(0xFF1B2432),
    onStrong: Color(0xFFF6F3EC),
    shadowSoft: Color(0x14212A38),
  );

  static const PlayColors dark = PlayColors(
    brightness: Brightness.dark,
    canvas: Color(0xFF14161A),
    surface: Color(0xFF1D2026),
    surfaceSunken: Color(0xFF0F1114),
    line: Color(0xFF2C313A),
    ink: Color(0xFFEDEFF3),
    inkMuted: Color(0xFFA3AAB6),
    inkFaint: Color(0xFF6C7480),
    primary: Color(0xFF8FA8D6),
    onPrimary: Color(0xFF14243C),
    primarySoft: Color(0xFF243149),
    onPrimarySoft: Color(0xFFC7D4EC),
    mint: Color(0xFF1D3A2B),
    onMint: Color(0xFFCDEEDB),
    pink: Color(0xFF3B2230),
    onPink: Color(0xFFF7D3E1),
    lemon: Color(0xFF3A3418),
    onLemon: Color(0xFFF3E7A8),
    sky: Color(0xFF1E2A44),
    onSky: Color(0xFFD2DEF4),
    coral: Color(0xFFF07C90),
    onCoral: Color(0xFF2A0A12),
    teal: Color(0xFF4FD1A8),
    onTeal: Color(0xFF04241B),
    strong: Color(0xFFEDEFF3),
    onStrong: Color(0xFF1B2432),
    shadowSoft: Color(0x66000000),
  );
}

/// Pins a [PlayColors] palette to a subtree.
///
/// The app always resolves from the platform brightness, but the widget
/// previewer (and a dark-mode preview embedded in a light page) benefits from
/// being able to force one explicitly.
class PlayTheme extends InheritedWidget {
  const PlayTheme({super.key, required this.colors, required super.child});

  final PlayColors colors;

  /// The palette pinned above [context], if any.
  static PlayColors? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayTheme>()?.colors;

  @override
  bool updateShouldNotify(PlayTheme oldWidget) =>
      !identical(oldWidget.colors, colors);
}
