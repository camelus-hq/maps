import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/entities/transit.dart';
import '../../../../state/commands/commands_provider.dart';
import '../../../../state/transit_departures.dart';
import '../../../common/error_text.dart';
import '../../../design/play.dart';
import 'transit_departure_row.dart';

/// The "Departures" board — the next departures from a stop, opened by tapping a
/// station on a journey timeline. It floats over whatever sheet is showing (the
/// directions detail or the live navigation sheet).
class TransitDeparturesSheet extends ConsumerWidget {
  const TransitDeparturesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayColors colors = PlayColors.of(context);
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
        return PlaySheet(
          radius: PlayRadii.lg,
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewPaddingOf(context).bottom + AppSpacing.md,
            ),
            children: <Widget>[
              const PlaySheetHandle(),
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
                            style: PlayType.title.copyWith(color: colors.ink),
                          ),
                          Text(
                            'From ${state.stopName ?? state.stopId ?? ''}',
                            style: PlayType.caption.copyWith(
                              color: colors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PlayIconButton(
                      icon: PlayIcons.close,
                      variant: PlayIconButtonVariant.plain,
                      size: 40,
                      semanticLabel: 'Close',
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: PlayDivider(),
              ),
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
    final PlayColors colors = PlayColors.of(context);
    switch (state.status) {
      case DeparturesStatus.loading:
      case DeparturesStatus.idle:
        return const <Widget>[
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: PlaySpinner()),
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
                Icon(presentation.icon, color: colors.inkFaint),
                const SizedBox(height: AppSpacing.sm),
                Text(presentation.text, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                PlayButton(
                  label: 'Retry',
                  icon: PlayIcons.refresh,
                  variant: PlayButtonVariant.ghost,
                  onPressed: () =>
                      ref.read(transitDeparturesProvider.notifier).retry(),
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
                  style: PlayType.body.copyWith(color: colors.ink),
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
