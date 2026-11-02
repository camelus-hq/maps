import 'package:flutter/widgets.dart';

/// The root navigator key, shared between the app router (which attaches it to
/// the [GoRouter]) and the `ui.back` control command (which pops through it).
///
/// Lives in L3 so the command registry can drive back-navigation without a
/// widget context; the app layer supplies the router it is attached to.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
