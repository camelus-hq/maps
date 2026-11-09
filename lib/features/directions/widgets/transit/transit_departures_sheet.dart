import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/entities/transit.dart';
import '../../../../state/commands/commands_provider.dart';
import '../../../../state/transit_departures.dart';
import '../../../common/error_text.dart';
import 'transit_common.dart';

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
            _DepartureRow(departure: departure),
        ];
    }
  }
}

/// One departure: the line badge, where it is headed and when it leaves.
class _DepartureRow extends StatelessWidget {
  const _DepartureRow({required this.departure});

  final TransitStopDeparture departure;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String status = transitDepartureStatus(departure);
    final bool bad = departure.cancelled;
    final DateTime when = departure.displayDeparture.toLocal();
    final DateTime now = DateTime.now();
    final bool past = when.isBefore(now);
    final String? relative = relativeTimeLabel(when, now: now);
    final String? track = departure.displayTrack;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _DepartureBadge(departure: departure),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  departure.headsign ?? departure.routeLongName ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: past ? scheme.outline : null),
                ),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        <String>[
                          status,
                          transitClock(context, when),
                          ?relative,
                          if (track != null) 'Platform $track',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: bad
                              ? scheme.error
                              : past
                              ? scheme.outline
                              : (departure.realTime
                                    ? scheme.primary
                                    : scheme.outline),
                        ),
                      ),
                    ),
                    if (departure.realTime && !bad && !past) ...<Widget>[
                      const SizedBox(width: 6),
                      const TransitLiveBadge(),
                    ],
                  ],
                ),
                if (departure.agencyName != null)
                  Text(
                    departure.agencyName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.outline),
                  ),
              ],
            ),
          ),
          if (departure.wheelchairAccessible || departure.bikesAllowed)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (departure.wheelchairAccessible)
                    Icon(Icons.accessible, size: 16, color: scheme.outline),
                  if (departure.bikesAllowed)
                    Icon(Icons.pedal_bike, size: 16, color: scheme.outline),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A coloured line badge for a departure row.
class _DepartureBadge extends StatelessWidget {
  const _DepartureBadge({required this.departure});

  final TransitStopDeparture departure;

  @override
  Widget build(BuildContext context) {
    final int background = departure.displayColor;
    final int foreground =
        departure.routeTextColor ??
        (Color(background).computeLuminance() > 0.5 ? 0xFF10161A : 0xFFFFFFFF);
    return Container(
      constraints: const BoxConstraints(minWidth: 34),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Color(background),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        departure.lineLabel,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: Color(foreground), fontWeight: FontWeight.w600),
      ),
    );
  }
}
