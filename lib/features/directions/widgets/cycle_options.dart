import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/cycling_options.dart';
import '../../../state/route.dart';

/// The bicycle cost options shown under the Cycle travel mode: the kind of
/// bike, and the Hills / surface / road / speed weights Valhalla's bicycle
/// costing exposes. Every change re-plans the route.
class CycleOptionsPanel extends ConsumerWidget {
  const CycleOptionsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Avoid edges'),
          subtitle: const Text('Skip dead-end roads'),
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

/// The `BicycleType` dropdown (Road / Hybrid / Cross / Mountain).
class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.value, required this.onChanged});

  final BicycleType value;
  final ValueChanged<BicycleType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text('Type', style: Theme.of(context).textTheme.bodyLarge),
        ),
        DropdownButton<BicycleType>(
          value: value,
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          onChanged: (BicycleType? next) {
            if (next != null) {
              onChanged(next);
            }
          },
          items: <DropdownMenuItem<BicycleType>>[
            for (final BicycleType type in BicycleType.values)
              DropdownMenuItem<BicycleType>(
                value: type,
                child: Text(type.label),
              ),
          ],
        ),
      ],
    );
  }
}

/// A labelled slider with a live hint on the right.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text(
              hint,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: hint,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}
