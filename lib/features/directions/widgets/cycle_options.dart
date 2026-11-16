import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/cycling_options.dart';
import '../../../state/route.dart';
import '../../design/play.dart';

/// The bicycle cost options shown under the Cycle travel mode: the kind of
/// bike, and the Hills / surface / road / speed weights Valhalla's bicycle
/// costing exposes. Every change re-plans the route.
class CycleOptionsPanel extends ConsumerWidget {
  const CycleOptionsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayColors colors = PlayColors.of(context);
    final CyclingOptions options = ref.watch(
      routeControllerProvider.select((RouteState s) => s.cycling),
    );
    final RouteController controller = ref.read(
      routeControllerProvider.notifier,
    );
    // A slider drag updates the value without re-planning on every pixel; the
    // drag end re-plans once.
    void preview(CyclingOptions next) =>
        unawaited(controller.setCyclingOptions(next, replan: false));
    void commit(CyclingOptions next) =>
        unawaited(controller.setCyclingOptions(next));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            'Bike',
            style: PlayType.bodyStrong.copyWith(color: colors.primary),
          ),
        ),
        _TypeRow(
          value: options.bicycleType,
          onChanged: (BicycleType type) => commit(
            // Follow the new type's default cruising speed (Valhalla does the
            // same); the rider can still override it afterwards.
            options.copyWith(bicycleType: type, clearCyclingSpeed: true),
          ),
        ),
        _OptionSlider(
          label: 'Hills',
          hint: _weightHint(options.useHills, low: 'Avoid', high: 'Prefer'),
          value: options.useHills,
          onChanged: (double v) => preview(options.copyWith(useHills: v)),
          onChangeEnd: (double v) => commit(options.copyWith(useHills: v)),
        ),
        _OptionSlider(
          label: 'Avoid bad surfaces',
          hint: '${(options.avoidBadSurfaces * 100).round()}%',
          value: options.avoidBadSurfaces,
          onChanged: (double v) =>
              preview(options.copyWith(avoidBadSurfaces: v)),
          onChangeEnd: (double v) =>
              commit(options.copyWith(avoidBadSurfaces: v)),
        ),
        _OptionSlider(
          label: 'Roads',
          hint: _weightHint(options.useRoads, low: 'Paths', high: 'Roads'),
          value: options.useRoads,
          onChanged: (double v) => preview(options.copyWith(useRoads: v)),
          onChangeEnd: (double v) => commit(options.copyWith(useRoads: v)),
        ),
        _OptionSlider(
          label: 'Speed',
          hint: '${options.effectiveCyclingSpeed.round()} km/h',
          value: options.effectiveCyclingSpeed.clamp(_minSpeed, _maxSpeed),
          min: _minSpeed,
          max: _maxSpeed,
          divisions: (_maxSpeed - _minSpeed).round(),
          onChanged: (double v) => preview(options.copyWith(cyclingSpeed: v)),
          onChangeEnd: (double v) => commit(options.copyWith(cyclingSpeed: v)),
        ),
        _SwitchRow(
          label: 'Avoid edges',
          subtitle: 'Skip dead-end roads',
          value: options.avoidEdges,
          onChanged: (bool value) =>
              commit(options.copyWith(avoidEdges: value)),
        ),
      ],
    );
  }

  static const double _minSpeed = 5;
  static const double _maxSpeed = 45;

  static String _weightHint(
    double value, {
    required String low,
    required String high,
  }) {
    if (value <= 0.01) {
      return low;
    }
    if (value >= 0.99) {
      return high;
    }
    return '${(value * 100).round()}%';
  }
}

/// The `BicycleType` chooser (Road / Hybrid / Cross / Mountain): the current
/// type with a chevron, opening a play sheet of the options.
class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.value, required this.onChanged});

  final BicycleType value;
  final ValueChanged<BicycleType> onChanged;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return PlayRow(
      label: 'Type',
      showChevron: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(value.label, style: PlayType.body.copyWith(color: colors.ink)),
          const SizedBox(width: 4),
          Icon(
            PhosphorIconsRegular.caretDown,
            size: 16,
            color: colors.inkFaint,
          ),
        ],
      ),
      onTap: () => unawaited(_choose(context)),
    );
  }

  Future<void> _choose(BuildContext context) async {
    final BicycleType? picked = await showPlaySheet<BicycleType>(
      context,
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          PlaySpace.lg,
          0,
          PlaySpace.lg,
          PlaySpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final BicycleType type in BicycleType.values)
              PlayRow(
                label: type.label,
                showChevron: false,
                trailing: type == value
                    ? Icon(
                        PlayIcons.check,
                        size: 20,
                        color: PlayColors.of(context).primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(type),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      onChanged(picked);
    }
  }
}

/// A labelled play slider with a live hint on the right.
class _OptionSlider extends StatelessWidget {
  const _OptionSlider({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.divisions = 20,
  });

  final String label;
  final String hint;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final double min;
  final double max;
  final int divisions;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: PlayType.body.copyWith(color: colors.ink),
              ),
            ),
            Text(
              hint,
              style: PlayType.caption.copyWith(color: colors.inkMuted),
            ),
          ],
        ),
        _PlaySlider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}

/// The play slider: a recessed track, a brand-coloured fill and a round thumb.
///
/// A hand-rolled replacement for Material's `Slider` (the play kit ships no
/// slider yet), supporting [min]/[max]/[divisions] and reporting a preview on
/// drag with a single commit at the end.
class _PlaySlider extends StatefulWidget {
  const _PlaySlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  State<_PlaySlider> createState() => _PlaySliderState();
}

class _PlaySliderState extends State<_PlaySlider> {
  static const double _thumb = 24;

  /// The value being dragged, shown instead of [widget.value] until released.
  double? _dragValue;

  double get _value => _dragValue ?? widget.value;

  double _valueFor(double dx, double width) {
    final double track = (width - _thumb).clamp(1, double.infinity);
    final double t = ((dx - _thumb / 2) / track).clamp(0.0, 1.0);
    final double raw = widget.min + t * (widget.max - widget.min);
    if (widget.divisions > 0) {
      final double step = (widget.max - widget.min) / widget.divisions;
      final double snapped =
          widget.min + ((raw - widget.min) / step).round() * step;
      return snapped.clamp(widget.min, widget.max);
    }
    return raw.clamp(widget.min, widget.max);
  }

  void _update(double dx, double width) {
    final double next = _valueFor(dx, width);
    setState(() => _dragValue = next);
    widget.onChanged(next);
  }

  void _commit() {
    final double? next = _dragValue;
    if (next == null) {
      return;
    }
    setState(() => _dragValue = null);
    widget.onChangeEnd(next);
  }

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final double span = widget.max - widget.min;
    final double fraction = span <= 0
        ? 0
        : ((_value - widget.min) / span).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails d) => _update(d.localPosition.dx, width),
          onTapUp: (TapUpDetails _) => _commit(),
          onHorizontalDragStart: (DragStartDetails d) =>
              _update(d.localPosition.dx, width),
          onHorizontalDragUpdate: (DragUpdateDetails d) =>
              _update(d.localPosition.dx, width),
          onHorizontalDragEnd: (DragEndDetails _) => _commit(),
          onHorizontalDragCancel: _commit,
          child: SizedBox(
            height: _thumb,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: <Widget>[
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken,
                    borderRadius: BorderRadius.circular(PlayRadii.pill),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(PlayRadii.pill),
                    ),
                  ),
                ),
                Positioned(
                  left: fraction * (width - _thumb),
                  child: Container(
                    width: _thumb,
                    height: _thumb,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary,
                      border: Border.all(color: colors.surface, width: 3),
                      boxShadow: PlayShadow.soft.resolve(colors),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A labelled on/off row with a [PlaySwitch].
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: PlayType.body.copyWith(color: colors.ink)),
              Text(
                subtitle,
                style: PlayType.caption.copyWith(color: colors.inkMuted),
              ),
            ],
          ),
        ),
        PlaySwitch(value: value, semanticLabel: label, onChanged: onChanged),
      ],
    );
  }
}
