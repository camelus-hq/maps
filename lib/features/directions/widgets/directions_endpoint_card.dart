import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/route.dart';
import '../../design/play.dart';

/// The floating directions header that overhangs the top of the map.
///
/// It replaces the search bar while directions are open and holds the start,
/// stop and destination rows. Tapping a row opens the endpoint place picker
/// (`route.editEndpoint`); the overflow menu adds a stop, swaps the endpoints or
/// clears the route. Like every control, each action goes through a command id
/// so the UI and the control channel share one code path.
class DirectionsEndpointCard extends ConsumerWidget {
  const DirectionsEndpointCard({super.key, this.onClose});

  /// Handles the leading back affordance; defaults to the `route.clear`
  /// command (exiting directions).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayColors colors = PlayColors.of(context);
    final RouteState state = ref.watch(routeControllerProvider);
    final registry = ref.read(commandRegistryProvider);

    void edit(String field, {int? index}) => unawaited(
      registry.dispatch('route.editEndpoint', <String, Object?>{
        'field': field,
        'index': ?index,
      }),
    );

    return PlaySurface(
      radius: AppSpacing.sheetRadius,
      padding: const EdgeInsets.all(4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PlayIconButton(
            icon: PlayIcons.back,
            variant: PlayIconButtonVariant.plain,
            semanticLabel: 'Exit directions',
            onPressed:
                onClose ??
                () => unawaited(
                  registry.dispatch('route.clear', const <String, Object?>{}),
                ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _EndpointRow(
                  icon: PhosphorIconsRegular.record,
                  color: colors.primary,
                  text: state.origin?.name ?? 'Choose a start',
                  placeholder: state.origin == null,
                  onTap: () => edit('origin'),
                ),
                for (int i = 0; i < state.stops.length; i++)
                  _EndpointRow(
                    icon: PhosphorIconsRegular.circle,
                    iconSize: 10,
                    color: colors.inkFaint,
                    text: state.stops[i].name,
                    onTap: () => edit('stop', index: i),
                    onRemove: () => unawaited(
                      registry.dispatch('route.removeStop', <String, Object?>{
                        'index': i,
                      }),
                    ),
                  ),
                _EndpointRow(
                  icon: PlayIcons.place,
                  color: colors.primary,
                  text: state.destination?.name ?? 'Choose a destination',
                  placeholder: state.destination == null,
                  onTap: () => edit('destination'),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PlayMenuButton<RouteMenu>(
                semanticLabel: 'Route options',
                onSelected: (RouteMenu value) => unawaited(_onMenu(ref, value)),
                items: <PlayMenuItem<RouteMenu>>[
                  PlayMenuItem<RouteMenu>(
                    value: RouteMenu.addStop,
                    label: 'Add stop',
                    icon: PlayIcons.contributePlace,
                  ),
                  const PlayMenuItem<RouteMenu>(
                    value: RouteMenu.swap,
                    label: 'Swap start and destination',
                    icon: PhosphorIconsRegular.arrowsDownUp,
                  ),
                  const PlayMenuItem<RouteMenu>(
                    value: RouteMenu.clear,
                    label: 'Clear route',
                    icon: PlayIcons.close,
                  ),
                ],
              ),
              PlayIconButton(
                icon: PhosphorIconsRegular.arrowsDownUp,
                variant: PlayIconButtonVariant.plain,
                semanticLabel: 'Swap start and destination',
                onPressed: () => unawaited(
                  registry.dispatch('route.swap', const <String, Object?>{}),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onMenu(WidgetRef ref, RouteMenu value) async {
    final registry = ref.read(commandRegistryProvider);
    switch (value) {
      case RouteMenu.addStop:
        // A stop needs a destination to attach to (the old menu greyed this out
        // when there was none; PlayMenuButton has no disabled state).
        if (ref.read(routeControllerProvider).destination == null) {
          return;
        }
        await registry.dispatch('route.editEndpoint', const <String, Object?>{
          'field': 'stop',
        });
      case RouteMenu.swap:
        await registry.dispatch('route.swap', const <String, Object?>{});
      case RouteMenu.clear:
        await registry.dispatch('route.clear', const <String, Object?>{});
    }
  }
}

enum RouteMenu { addStop, swap, clear }

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({
    required this.icon,
    required this.color,
    required this.text,
    required this.onTap,
    this.placeholder = false,
    this.iconSize = 18,
    this.onRemove,
  });

  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;
  final bool placeholder;
  final double iconSize;

  /// When set, a trailing remove button is shown (an existing stop).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    // The remove button is a sibling of the tappable row, not a child: a nested
    // pressable loses the tap to the row, so a tap on ✕ used to open the stop
    // editor instead of removing the stop.
    return Row(
      children: <Widget>[
        Expanded(
          child: PlayPressable(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 24,
                    child: Center(
                      child: Icon(icon, size: iconSize, color: color),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PlayType.body.copyWith(
                        color: placeholder ? colors.inkMuted : colors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onRemove != null)
          PlayIconButton(
            icon: PlayIcons.close,
            variant: PlayIconButtonVariant.plain,
            size: 32,
            iconSize: 16,
            semanticLabel: 'Remove stop',
            onPressed: onRemove,
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(PlayIcons.next, size: 18, color: colors.inkFaint),
          ),
      ],
    );
  }
}
