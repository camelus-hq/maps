import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/map_style.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/map_layers.dart';
import '../../design/play.dart';

/// Presents the layers switcher (base map style + traffic overlay) as a play
/// modal sheet.
Future<void> showLayersSheet(BuildContext context) async {
  await showPlaySheet<void>(
    context,
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
    final PlayColors colors = PlayColors.of(context);
    return Padding(
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
          Text('Map type', style: PlayType.title.copyWith(color: colors.ink)),
          const SizedBox(height: PlaySpace.md),
          Wrap(
            spacing: PlaySpace.sm,
            runSpacing: PlaySpace.sm,
            children: <Widget>[
              for (final BaseMapStyle option in BaseMapStyle.values)
                PlayChip(
                  label: _label(option),
                  icon: _icon(option),
                  selected: option == style,
                  onTap: () => unawaited(
                    ref.read(commandRegistryProvider).dispatch(
                      'map.style.set',
                      <String, Object?>{'style': option.name},
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: PlaySpace.lg),
          const PlayDivider(),
          PlayRow(
            icon: PlayIcons.traffic,
            label: 'Traffic',
            subtitle: 'Realtime conditions overlay',
            showChevron: false,
            trailing: PlaySwitch(
              value: traffic,
              semanticLabel: 'Traffic overlay',
              onChanged: (bool value) => unawaited(
                ref.read(commandRegistryProvider).dispatch(
                  'map.traffic',
                  <String, Object?>{'on': value},
                ),
              ),
            ),
          ),
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
    BaseMapStyle.standard => PlayIcons.mapStandard,
    BaseMapStyle.satellite => PlayIcons.mapSatellite,
    BaseMapStyle.terrain => PlayIcons.mapTerrain,
  };
}
