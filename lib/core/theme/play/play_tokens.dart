import 'package:flutter/painting.dart';

/// Corner radii. Play leans on generous, almost pill-shaped rounding — a big
/// part of what makes the surfaces read as playful rather than Material.
abstract final class PlayRadii {
  static const double xs = 10;
  static const double sm = 14;
  static const double md = 20;
  static const double lg = 28;
  static const double xl = 36;

  /// Fully round (pill / circle).
  static const double pill = 999;
}

/// Layout spacing scale.
abstract final class PlaySpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// The Play type ramp.
///
/// Uses the platform's system font (Roboto on Android, per AGENTS.md — no
/// bundled proprietary font) but pushes weight and tracking hard: heavy
/// weights with tight negative tracking for display, wide positive tracking for
/// the tiny all-caps overline. Colours are applied by the widgets, so these are
/// all colour-less.
abstract final class PlayType {
  /// Hero headline (screen titles, onboarding).
  static const TextStyle display = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    height: 1.05,
    letterSpacing: -0.8,
  );

  /// Section headline.
  static const TextStyle headline = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -0.5,
  );

  /// Card / sheet title.
  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.3,
  );

  /// List row title.
  static const TextStyle subtitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.2,
  );

  /// Default body copy.
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Emphasised body copy (button labels, values).
  static const TextStyle bodyStrong = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.1,
  );

  /// Secondary copy.
  static const TextStyle caption = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );

  /// Tiny all-caps label (tags, overlines).
  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    height: 1,
    letterSpacing: 1.2,
  );

  /// The big number on a stat card.
  static const TextStyle stat = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1,
    letterSpacing: -0.9,
  );
}
