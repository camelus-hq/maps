import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_tokens.dart';
import '../atoms/play_icon_button.dart';
import '../play_icons.dart';
import '../play_previews.dart';

/// One control in a [PlayMapControlRail].
@immutable
class PlayMapControl {
  const PlayMapControl({
    required this.icon,
    required this.semanticLabel,
    this.onTap,
    this.active = false,
    this.alert = false,
    this.rotation = 0,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final bool active;
  final bool alert;

  /// Rotates the glyph (a compass needle), in radians.
  final double rotation;
}

/// The floating vertical stack of map controls (layers, compass, my-location).
///
/// A thin composition over [PlayIconButton] so the rail keeps the same press
/// feel and colour states as every other control.
class PlayMapControlRail extends StatelessWidget {
  const PlayMapControlRail({
    super.key,
    required this.controls,
    this.size = 48,
    this.spacing = PlaySpace.sm,
  });

  final List<PlayMapControl> controls;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < controls.length; i++) ...<Widget>[
          PlayIconButton(
            icon: controls[i].icon,
            size: size,
            active: controls[i].active,
            alert: controls[i].alert,
            rotation: controls[i].rotation,
            semanticLabel: controls[i].semanticLabel,
            onPressed: controls[i].onTap,
          ),
          if (i < controls.length - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }
}

@PlayPreview(name: 'PlayMapControlRail', size: Size(360, 340))
Widget playMapControlRailPreview() {
  return PlayPreviewFrame(
    child: PlayMapControlRail(
      controls: <PlayMapControl>[
        PlayMapControl(
          icon: PlayIcons.layers,
          semanticLabel: 'Layers',
          onTap: () {},
        ),
        PlayMapControl(
          icon: PlayIcons.navigation,
          semanticLabel: 'Reset bearing',
          rotation: 0.4,
          onTap: () {},
        ),
        const PlayMapControl(
          icon: PlayIcons.locate,
          semanticLabel: 'Following your location',
          active: true,
        ),
        const PlayMapControl(
          icon: PlayIcons.locationLost,
          semanticLabel: 'Location unavailable',
          alert: true,
        ),
      ],
    ),
  );
}
