// ndk_flutter is built on the deprecated `package:flutter/material.dart`
// library, and this is the only place OpenMaps still has to import it.
//
// The widget types of `package:flutter/material.dart` and the replacement
// `package:material_ui/material_ui.dart` are *distinct libraries* with the same
// names: `material_ui`'s `Material` does not satisfy `material.dart`'s
// `TextField`, which asserts a `Material` ancestor of its own library. So a
// third-party Material widget (only `NLogin` today) needs a `material.dart`
// ancestor, and the deprecated import is unavoidable for that one seam.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// Hosts a widget built from the deprecated `package:flutter/material.dart`
/// library (currently only ndk_flutter's `NLogin`) in the transparent
/// `Material` ancestor it requires.
///
/// Nothing is painted ([MaterialType.transparency]), so the Play canvas shows
/// through and the rest of the app stays on the Play design system.
class MaterialHost extends StatelessWidget {
  const MaterialHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(type: MaterialType.transparency, child: child);
  }
}
