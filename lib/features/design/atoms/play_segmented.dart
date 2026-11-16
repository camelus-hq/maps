import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import '../play_previews.dart';
import 'play_pressable.dart';
import 'play_surface.dart';

/// One choice in a [PlaySegmented].
@immutable
class PlaySegment<T> {
  const PlaySegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// A segmented single-choice control — the play replacement for Material's
/// `SegmentedButton`.
///
/// The selected segment lifts onto a surface-coloured pill inside a recessed
/// track.
class PlaySegmented<T> extends StatelessWidget {
  const PlaySegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<PlaySegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return PlaySurface(
      tone: PlayTone.sunken,
      radius: PlayRadii.pill,
      shadow: PlayShadow.none,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: <Widget>[
          for (final PlaySegment<T> segment in segments)
            Expanded(
              child: _Segment<T>(
                segment: segment,
                selected: segment.value == selected,
                colors: colors,
                onTap: () => onChanged(segment.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final PlaySegment<T> segment;
  final bool selected;
  final PlayColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected ? colors.ink : colors.inkMuted;
    return PlayPressable(
      onTap: onTap,
      scale: 0.97,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.surface : const Color(0x00000000),
          borderRadius: BorderRadius.circular(PlayRadii.pill),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (segment.icon != null) ...<Widget>[
              Icon(segment.icon, size: 16, color: foreground),
              const SizedBox(width: PlaySpace.xs),
            ],
            Text(
              segment.label,
              style: PlayType.bodyStrong.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

@PlayPreview(name: 'PlaySegmented', size: Size(420, 160))
Widget playSegmentedPreview() {
  return PlayPreviewFrame(
    child: PlaySegmented<String>(
      selected: 'metric',
      onChanged: (String _) {},
      segments: const <PlaySegment<String>>[
        PlaySegment<String>(value: 'metric', label: 'Metric'),
        PlaySegment<String>(value: 'imperial', label: 'Imperial'),
      ],
    ),
  );
}
