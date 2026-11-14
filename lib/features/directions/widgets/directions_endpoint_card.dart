import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/route.dart';

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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final RouteState state = ref.watch(routeControllerProvider);
    final registry = ref.read(commandRegistryProvider);

    void edit(String field, {int? index}) => unawaited(
      registry.dispatch('route.editEndpoint', <String, Object?>{
        'field': field,
        'index': ?index,
      }),
    );

    return Material(
      color: scheme.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Exit directions',
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
                    icon: Icons.trip_origin,
                    color: scheme.primary,
                    text: state.origin?.name ?? 'Choose a start',
                    placeholder: state.origin == null,
                    onTap: () => edit('origin'),
                  ),
                  for (int i = 0; i < state.stops.length; i++)
                    _EndpointRow(
                      icon: Icons.circle,
                      iconSize: 10,
                      color: scheme.outline,
                      text: state.stops[i].name,
                      onTap: () => edit('stop', index: i),
                      onRemove: () => unawaited(
                        registry.dispatch('route.removeStop', <String, Object?>{
                          'index': i,
                        }),
                      ),
                    ),
                  _EndpointRow(
                    icon: Icons.place,
                    color: scheme.primary,
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
                PopupMenuButton<RouteMenu>(
                  tooltip: 'Route options',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (RouteMenu value) =>
                      unawaited(_onMenu(ref, value)),
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<RouteMenu>>[
                        PopupMenuItem<RouteMenu>(
                          value: RouteMenu.addStop,
                          enabled: state.destination != null,
                          child: const _MenuRow(
                            icon: Icons.add_location_alt_outlined,
                            label: 'Add stop',
                          ),
                        ),
                        const PopupMenuItem<RouteMenu>(
                          value: RouteMenu.swap,
                          child: _MenuRow(
                            icon: Icons.swap_vert,
                            label: 'Swap start and destination',
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem<RouteMenu>(
                          value: RouteMenu.clear,
                          child: _MenuRow(
                            icon: Icons.close,
                            label: 'Clear route',
                          ),
                        ),
                      ],
                ),
                IconButton(
                  icon: const Icon(Icons.swap_vert),
                  tooltip: 'Swap start and destination',
                  onPressed: () => unawaited(
                    registry.dispatch('route.swap', const <String, Object?>{}),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onMenu(WidgetRef ref, RouteMenu value) async {
    final registry = ref.read(commandRegistryProvider);
    switch (value) {
      case RouteMenu.addStop:
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

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

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
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    // The remove button is a sibling of the tappable row, not a child: a nested
    // InkWell loses the tap to the row, so a tap on ✕ used to open the stop
    // editor instead of removing the stop.
    return Row(
      children: <Widget>[
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
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
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: placeholder ? scheme.onSurfaceVariant : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onRemove != null)
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: 'Remove stop',
            visualDensity: VisualDensity.compact,
            color: scheme.outline,
            onPressed: onRemove,
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(Icons.chevron_right, size: 18, color: scheme.outline),
          ),
      ],
    );
  }
}
