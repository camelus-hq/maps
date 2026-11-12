import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/transit.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/transit_stop_board.dart';
import '../../common/error_text.dart';
import '../../directions/widgets/transit/transit_departure_row.dart';
import '../../directions/widgets/transit/transit_line_chip.dart';

/// The line chips for the stop the station sheet is open on: every bus, tram,
/// subway, train and ferry line that serves it, in the operator's own colour.
///
/// Shown in the sheet summary as soon as the stop's lines have loaded, so a
/// tapped station advertises what runs there (like the other transit screens).
class PlaceStopLines extends ConsumerWidget {
  const PlaceStopLines({super.key});

  /// Bound on the chips shown, so a mega-interchange cannot grow the summary
  /// without limit (the rest are summarised as "+N").
  static const int _maxChips = 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TransitStopBoardState state = ref.watch(transitStopBoardProvider);
    final List<TransitStopRoute> routes = state.routes;
    if (routes.isEmpty) {
      return const SizedBox.shrink();
    }
    final List<TransitStopRoute> shown = routes.length <= _maxChips
        ? routes
        : routes.sublist(0, _maxChips);
    final int hidden = routes.length - shown.length;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          for (final TransitStopRoute route in shown)
            TransitLineChip(
              label: route.lineLabel,
              color: route.displayColor,
              textColor: route.routeTextColor,
            ),
          if (hidden > 0)
            Text(
              '+$hidden',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// The Departures tab of the station sheet: the lines serving the stop, the
/// next departures with a **load earlier** control above the list and a **load
/// later** control below it.
class PlaceDeparturesTab extends ConsumerWidget {
  const PlaceDeparturesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TransitStopBoardState state = ref.watch(transitStopBoardProvider);

    if (state.isLoading && state.departures.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.status == StopBoardStatus.error && state.departures.isEmpty) {
      return _ErrorState(error: state.error);
    }
    if (state.departures.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Text(
            'No departures found for this stop',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _LoadControl(
          label: 'Earlier departures',
          icon: Icons.keyboard_arrow_up,
          loading: state.loadingEarlier,
          visible: state.hasEarlier,
          command: 'transit.stop.earlier',
        ),
        for (final TransitStopDeparture departure in state.departures)
          TransitDepartureRow(departure: departure),
        _LoadControl(
          label: 'Later departures',
          icon: Icons.keyboard_arrow_down,
          loading: state.loadingLater,
          visible: state.hasLater,
          command: 'transit.stop.later',
        ),
      ],
    );
  }
}

/// A full-width "load earlier/later departures" control with a spinner while it
/// loads.
class _LoadControl extends ConsumerWidget {
  const _LoadControl({
    required this.label,
    required this.icon,
    required this.loading,
    required this.visible,
    required this.command,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final bool visible;
  final String command;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!visible && !loading) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: TextButton.icon(
        onPressed: loading
            ? null
            : () => ref
                  .read(commandRegistryProvider)
                  .dispatch(command, const <String, Object?>{}),
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _ErrorState extends ConsumerWidget {
  const _ErrorState({this.error});

  final AppException? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ({IconData icon, String text}) presentation = errorPresentation(
      error,
      fallback: 'Could not load departures',
    );
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: <Widget>[
          Icon(presentation.icon, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: AppSpacing.sm),
          Text(presentation.text, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(transitStopBoardProvider.notifier).retry(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
