import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/entities/transit.dart';
import '../../../../state/commands/commands_provider.dart';
import '../../../../state/transit_departures.dart';
import '../../../common/error_text.dart';
import 'transit_departure_row.dart';

/// The "Departures" board — the next departures from a stop, opened by tapping a
/// station on a journey timeline. It floats over whatever sheet is showing (the
/// directions detail or the live navigation sheet).
class TransitDeparturesSheet extends ConsumerWidget {
  const TransitDeparturesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TransitDeparturesState state = ref.watch(transitDeparturesProvider);
    if (!state.isOpen) {
      return const SizedBox.shrink();
    }
    // A plain DraggableScrollableSheet (not MapSheet): the departures board
    // floats over the journey sheet but must not claim the map chrome's sheet
    // anchor, so the controls stay attached to the sheet underneath.
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.2,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const <double>[0.2, 0.5, 0.85],
      builder: (BuildContext context, ScrollController scrollController) {
        return Material(
          color: scheme.surface,
          elevation: 16,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewPaddingOf(context).bottom + AppSpacing.md,
            ),
            children: <Widget>[
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Departures',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'From ${state.stopName ?? state.stopId ?? ''}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => ref
                          .read(commandRegistryProvider)
                          .dispatch(
                            'transit.departures.close',
                            const <String, Object?>{},
                          ),
                    ),
                  ],
                ),
              ),
              const Divider(height: AppSpacing.md),
              ..._body(context, ref, state),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _body(
    BuildContext context,
    WidgetRef ref,
    TransitDeparturesState state,
  ) {
    switch (state.status) {
      case DeparturesStatus.loading:
      case DeparturesStatus.idle:
        return const <Widget>[
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      case DeparturesStatus.error:
        final ({IconData icon, String text}) presentation = errorPresentation(
          state.error,
          fallback: 'Could not load departures',
        );
        return <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: <Widget>[
                Icon(
                  presentation.icon,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(presentation.text, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(transitDeparturesProvider.notifier).retry(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ];
      case DeparturesStatus.data:
        if (state.departures.isEmpty) {
          return <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: Text(
                  'No more departures today',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ];
        }
        return <Widget>[
          for (final TransitStopDeparture departure in state.departures)
            TransitDepartureRow(departure: departure),
        ];
    }
  }
}
