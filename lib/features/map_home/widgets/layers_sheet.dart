import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/map_style.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/map_layers.dart';

/// Presents the layers switcher (base map style + traffic overlay).
Future<void> showLayersSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) => const LayersSheet(),
  );
}

/// Bottom sheet letting the user pick the base map style and toggle traffic.
class LayersSheet extends ConsumerWidget {
  const LayersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BaseMapStyle style = ref.watch(mapStyleProvider);
    final bool traffic = ref.watch(trafficProvider);
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'Map type',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final BaseMapStyle option in BaseMapStyle.values)
                  ChoiceChip(
                    label: Text(_label(option)),
                    avatar: Icon(_icon(option), size: 18),
                    selected: option == style,
                    onSelected: (_) => unawaited(
                      ref.read(commandRegistryProvider).dispatch(
                        'map.style.set',
                        <String, Object?>{'style': option.name},
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.traffic_outlined),
            title: const Text('Traffic'),
            subtitle: const Text('Realtime conditions overlay'),
            value: traffic,
            onChanged: (bool value) => unawaited(
              ref.read(commandRegistryProvider).dispatch(
                'map.traffic',
                <String, Object?>{'on': value},
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  static String _label(BaseMapStyle style) => switch (style) {
    BaseMapStyle.standard => 'Default',
    BaseMapStyle.satellite => 'Satellite',
    BaseMapStyle.terrain => 'Terrain',
  };

  static IconData _icon(BaseMapStyle style) => switch (style) {
    BaseMapStyle.standard => Icons.map_outlined,
    BaseMapStyle.satellite => Icons.satellite_alt_outlined,
    BaseMapStyle.terrain => Icons.terrain_outlined,
  };
}
