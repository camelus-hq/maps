import 'package:flutter/widgets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// The play kit's icon vocabulary: semantic names mapped to Phosphor glyphs.
///
/// Centralising the set keeps the kit's icons consistent and makes swapping the
/// icon family a one-file change. All glyphs are Phosphor Icons (MIT) — the same
/// family the place/category table already uses (see `place_result_icon.dart`).
abstract final class PlayIcons {
  // Chrome ----------------------------------------------------------------
  static const IconData search = PhosphorIconsRegular.magnifyingGlass;
  static const IconData brand = PhosphorIconsRegular.compass;
  static const IconData microphone = PhosphorIconsRegular.microphone;
  static const IconData user = PhosphorIconsRegular.user;
  static const IconData tune = PhosphorIconsRegular.faders;
  static const IconData close = PhosphorIconsRegular.x;
  static const IconData more = PhosphorIconsRegular.dotsThree;
  static const IconData back = PhosphorIconsRegular.caretLeft;
  static const IconData next = PhosphorIconsRegular.caretRight;

  // Bottom navigation (line + filled halves) ------------------------------
  static const IconData explore = PhosphorIconsRegular.compass;
  static const IconData exploreFilled = PhosphorIconsFill.compass;
  static const IconData person = PhosphorIconsRegular.user;
  static const IconData personFilled = PhosphorIconsFill.user;
  static const IconData contribute = PhosphorIconsRegular.plusCircle;
  static const IconData contributeFilled = PhosphorIconsFill.plusCircle;

  // Map controls ----------------------------------------------------------
  static const IconData layers = PhosphorIconsRegular.stack;
  static const IconData navigation = PhosphorIconsRegular.navigationArrow;
  static const IconData locate = PhosphorIconsRegular.crosshair;
  static const IconData locationLost = PhosphorIconsRegular.gpsSlash;

  // Map layers ------------------------------------------------------------
  static const IconData mapStandard = PhosphorIconsRegular.mapTrifold;
  static const IconData mapSatellite = PhosphorIconsRegular.globeHemisphereWest;
  static const IconData mapTerrain = PhosphorIconsRegular.mountains;
  static const IconData traffic = PhosphorIconsRegular.trafficSignal;

  // Feed / lists ----------------------------------------------------------
  static const IconData nearby = PhosphorIconsRegular.navigationArrow;
  static const IconData friends = PhosphorIconsRegular.usersThree;
  static const IconData recent = PhosphorIconsRegular.clockCounterClockwise;
  static const IconData saved = PhosphorIconsRegular.star;
  static const IconData savedFilled = PhosphorIconsFill.star;
  static const IconData loading = PhosphorIconsRegular.hourglass;
  static const IconData error = PhosphorIconsRegular.warningCircle;
  static const IconData contributePlace = PhosphorIconsRegular.mapPinPlus;

  // Actions ---------------------------------------------------------------
  static const IconData arrowRight = PhosphorIconsRegular.arrowRight;
  static const IconData lock = PhosphorIconsRegular.lock;
  static const IconData directions = PhosphorIconsRegular.signpost;
  static const IconData save = PhosphorIconsRegular.bookmarkSimple;
  static const IconData add = PhosphorIconsRegular.plus;
  static const IconData clock = PhosphorIconsRegular.clock;
  static const IconData route = PhosphorIconsRegular.path;
  static const IconData liveDot = PhosphorIconsFill.circle;
  static const IconData dot = PhosphorIconsRegular.circle;

  // Categories (a small, kit-local subset; the app keeps the full table in
  // `place_result_icon.dart`). -------------------------------------------
  static const IconData place = PhosphorIconsRegular.mapPin;
  static const IconData cafe = PhosphorIconsRegular.coffee;
  static const IconData park = PhosphorIconsRegular.tree;
  static const IconData water = PhosphorIconsRegular.drop;
  static const IconData fuel = PhosphorIconsRegular.gasPump;
  static const IconData groceries = PhosphorIconsRegular.shoppingCart;
  static const IconData bank = PhosphorIconsRegular.bank;
  static const IconData food = PhosphorIconsRegular.forkKnife;
  static const IconData hotel = PhosphorIconsRegular.bed;
}
