import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../play_previews.dart';
import 'play_pressable.dart';

/// A pill toggle — the play replacement for Material's `Switch`.
///
/// The whole row taps (not just a small target), the track fills with the brand
/// colour when on, and the thumb glides across.
class PlaySwitch extends StatelessWidget {
  const PlaySwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final bool enabled = onChanged != null;
    final Color track = value ? colors.primary : colors.surfaceSunken;
    final Color thumb = value ? colors.onPrimary : colors.inkFaint;

    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: PlayPressable(
          enabled: enabled,
          scale: 0.92,
          onTap: enabled ? () => onChanged?.call(!value) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 52,
            height: 30,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: track,
              borderRadius: BorderRadius.circular(PlayRadii.pill),
              border: Border.all(
                color: value ? const Color(0x00000000) : colors.line,
              ),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: thumb, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@PlayPreview(name: 'PlaySwitch', size: Size(320, 160))
Widget playSwitchPreview() {
  return PlayPreviewFrame(
    child: Builder(
      builder: (BuildContext context) {
        final PlayColors colors = PlayColors.of(context);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PlaySwitch(
              value: true,
              semanticLabel: 'On',
              onChanged: (bool _) {},
            ),
            const SizedBox(width: PlaySpace.xl),
            PlaySwitch(
              value: false,
              semanticLabel: 'Off',
              onChanged: (bool _) {},
            ),
            const SizedBox(width: PlaySpace.xl),
            const PlaySwitch(value: true, semanticLabel: 'Disabled'),
            const SizedBox(width: PlaySpace.lg),
            Text(
              'on · off · disabled',
              style: PlayType.caption.copyWith(color: colors.inkMuted),
            ),
          ],
        );
      },
    ),
  );
}
