import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/entities/transit.dart';
import '../../../../state/route.dart';
import '../../../common/error_text.dart';
import 'transit_common.dart';
import 'transit_itinerary_card.dart';

/// Step 1 of the transit flow: when to leave, what to prefer, and the list of
/// journeys. Tapping a journey opens its detail (step 2).
class TransitSection extends ConsumerWidget {
  const TransitSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RouteState state = ref.watch(routeControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _TimeChips(state: state),
        const SizedBox(height: AppSpacing.sm),
        _PreferRow(state: state),
        const SizedBox(height: AppSpacing.sm),
        _RoutePreferenceRow(state: state),
        const SizedBox(height: AppSpacing.md),
        _TransitBody(state: state),
      ],
    );
  }
}

/// "Leave now / Depart at / Arrive by". Choosing a departure or arrival opens a
/// date-then-time picker; the chosen time is shown and can be changed.
class _TimeChips extends ConsumerWidget {
  const _TimeChips({required this.state});

  final RouteState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RouteController controller = ref.read(
      routeControllerProvider.notifier,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: ChoiceChip(
                  label: const Text('Leave now'),
                  selected: state.transitTimeMode == TransitTimeMode.leaveNow,
                  onSelected: (bool _) => unawaited(
                    controller.setTransitTimeOfDay(
                      TransitTimeMode.leaveNow,
                      null,
                    ),
                  ),
                ),
              ),
              for (final (TransitTimeMode mode, String label)
                  in const <(TransitTimeMode, String)>[
                    (TransitTimeMode.departAt, 'Depart at'),
                    (TransitTimeMode.arriveBy, 'Arrive by'),
                  ])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: state.transitTimeMode == mode,
                    onSelected: (bool _) => unawaited(
                      _pickDateTime(context, ref, controller, mode),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (state.transitTimeMode != TransitTimeMode.leaveNow)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => unawaited(
                _pickDateTime(context, ref, controller, state.transitTimeMode),
              ),
              icon: const Icon(Icons.schedule),
              label: Text(
                transitClock(
                  context,
                  (state.transitTime ?? DateTime.now()).toLocal(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Opens a date picker then a time picker and re-plans with the result.
  Future<void> _pickDateTime(
    BuildContext context,
    WidgetRef ref,
    RouteController controller,
    TransitTimeMode mode,
  ) async {
    final DateTime now = DateTime.now();
    final DateTime initial =
        state.transitTime ?? now.add(const Duration(minutes: 5));
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return;
    }
    await controller.setTransitTimeOfDay(
      mode,
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }
}

/// The "Prefer Bus / Subway / Train / Tram" filter chips.
class _PreferRow extends ConsumerWidget {
  const _PreferRow({required this.state});

  final RouteState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LabelledChips(
      label: 'Prefer',
      children: <Widget>[
        for (final TransitModeGroup group in const <TransitModeGroup>[
          TransitModeGroup.bus,
          TransitModeGroup.subway,
          TransitModeGroup.train,
          TransitModeGroup.tram,
        ])
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              avatar: Icon(transitModeIcon(group.modes.first), size: 18),
              label: Text(group.label),
              selected: group.modes.every(state.transitModes.contains),
              onSelected: (bool _) => unawaited(
                ref
                    .read(routeControllerProvider.notifier)
                    .toggleTransitGroup(group),
              ),
            ),
          ),
      ],
    );
  }
}

/// The "Fewer transfers / Less walking" ranking chips.
class _RoutePreferenceRow extends ConsumerWidget {
  const _RoutePreferenceRow({required this.state});

  final RouteState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RouteController controller = ref.read(
      routeControllerProvider.notifier,
    );
    return _LabelledChips(
      label: 'Route',
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: FilterChip(
            label: const Text('Fewer transfers'),
            selected: state.fewerTransfers,
            onSelected: (bool value) =>
                unawaited(controller.setFewerTransfers(value)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: FilterChip(
            label: const Text('Less walking'),
            selected: state.lessWalking,
            onSelected: (bool value) =>
                unawaited(controller.setLessWalking(value)),
          ),
        ),
      ],
    );
  }
}

class _LabelledChips extends StatelessWidget {
  const _LabelledChips({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 56,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: children),
          ),
        ),
      ],
    );
  }
}

class _TransitBody extends ConsumerWidget {
  const _TransitBody({required this.state});

  final RouteState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (state.status) {
      case RouteStatus.loading:
        return const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        );
      case RouteStatus.error:
        final ({IconData icon, String text}) presentation = errorPresentation(
          state.error,
          fallback: 'Could not find a journey',
        );
        return _TransitError(
          icon: presentation.icon,
          message: presentation.text,
          onRetry: () =>
              unawaited(ref.read(routeControllerProvider.notifier).retry()),
        );
      case RouteStatus.idle:
        return const SizedBox.shrink();
      case RouteStatus.data:
        if (state.itineraries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text('No journeys found for this time.'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < state.itineraries.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: TransitItineraryCard(
                  itinerary: state.itineraries[i],
                  selected: i == state.selectedItineraryIndex,
                  // Step 2: open the journey detail.
                  onTap: () => ref
                      .read(routeControllerProvider.notifier)
                      .openTransitDetail(i),
                ),
              ),
          ],
        );
    }
  }
}

class _TransitError extends StatelessWidget {
  const _TransitError({
    required this.message,
    required this.onRetry,
    this.icon = Icons.error_outline,
  });

  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: <Widget>[
          Icon(icon, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
