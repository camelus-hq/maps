import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/place_category.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/home.dart';
import '../../../state/settings.dart';
import '../../common/navigation.dart';
import '../../common/place_result_icon.dart';
import '../../design/play.dart';
import 'category_picker_sheet.dart';

/// Horizontally scrolling category chips beneath the search bar, in the play
/// style.
///
/// The chips are the user's pinned categories (default Parks · Cafes · Water
/// fountain · Groceries · Toilets) followed a settings chip that opens the
/// category picker. Tapping a chip selects it — the map stays visible with the
/// places pinned and a results sheet — and tapping it again deselects and
/// clears them (`search.category` — the same path agents use).
class CategoryChips extends ConsumerWidget {
  const CategoryChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<PlaceCategory> pinned = ref.watch(pinnedCategoriesProvider);
    final String? selected = ref.watch(selectedCategoryProvider);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: PlaySpace.lg),
        children: <Widget>[
          for (int i = 0; i < pinned.length; i++) ...<Widget>[
            _CategoryChip(
              category: pinned[i],
              selected: selected == pinned[i].label,
            ),
            const SizedBox(width: PlaySpace.sm),
          ],
          const _CategorySettingsChip(),
        ],
      ),
    );
  }
}

class _CategoryChip extends ConsumerWidget {
  const _CategoryChip({required this.category, required this.selected});

  final PlaceCategory category;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlayChip(
      label: category.label,
      icon: placeResultIcon(category.id),
      selected: selected,
      onTap: () => unawaited(_select(context, ref, !selected)),
    );
  }

  /// Selects (browsing the category over the map) or deselects (clears it).
  ///
  /// The browse is a pushed route so the back gesture dismisses it.
  Future<void> _select(BuildContext context, WidgetRef ref, bool value) async {
    await ref.read(commandRegistryProvider).dispatch(
      'search.category',
      <String, Object?>{'name': value ? category.id : null},
    );
    if (!context.mounted) {
      return;
    }
    if (value) {
      openCategory(context);
    } else {
      closeCategory(context);
    }
  }
}

/// The trailing settings chip: opens the category picker.
class _CategorySettingsChip extends StatelessWidget {
  const _CategorySettingsChip();

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return PlaySurface(
      radius: PlayRadii.pill,
      borderWidth: 1,
      shadow: PlayShadow.soft,
      padding: const EdgeInsets.all(PlaySpace.sm),
      onTap: () => unawaited(showCategoryPicker(context)),
      child: SizedBox(
        width: 24,
        height: 24,
        child: Center(
          child: Semantics(
            label: 'Choose categories',
            child: Icon(PlayIcons.tune, size: 18, color: colors.inkMuted),
          ),
        ),
      ),
    );
  }
}

@PlayPreview(name: 'CategoryChips', size: Size(560, 120))
Widget categoryChipsPreview() {
  return PlayPreviewFrame(
    alignment: Alignment.topLeft,
    child: const ProviderScope(child: CategoryChips()),
  );
}
