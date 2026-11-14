import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/home.dart';
import '../../../state/search.dart';

/// The "Search this area" affordance: shown when results are on screen but the
/// map has been panned away from them. Re-runs the last query (or category).
class SearchAreaChip extends ConsumerWidget {
  const SearchAreaChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(searchAreaVisibleProvider)) {
      return const SizedBox.shrink();
    }
    final String? query = ref.watch(
      searchControllerProvider.select((SearchState state) => state.lastQuery),
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Align(
        alignment: Alignment.center,
        child: ActionChip(
          avatar: const Icon(Icons.search, size: 18),
          label: const Text('Search this area'),
          onPressed: () => unawaited(_rerun(ref, query)),
        ),
      ),
    );
  }

  Future<void> _rerun(WidgetRef ref, String? query) async {
    final String? category = ref.read(selectedCategoryProvider);
    final registry = ref.read(commandRegistryProvider);
    if (category != null) {
      // The map stays visible; the browse re-runs around the new viewport.
      await registry.dispatch('search.category', <String, Object?>{
        'name': category,
      });
    } else if (query != null) {
      await registry.dispatch('search.query', <String, Object?>{'text': query});
    }
  }
}
