import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/place_category.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/home.dart';
import '../../../state/settings.dart';
import 'category_icons.dart';
import 'category_picker_sheet.dart';

@Preview()
Widget categoryChipsPreview() {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: Column(
          children: const <Widget>[SizedBox(height: 50), CategoryChips()],
        ),
      ),
    ),
  );
}

/// Horizontally scrolling category chips beneath the search bar.
///
/// The chips are the user's pinned categories (default Parks · Cafes · Water
/// fountain · Groceries · Toilets) followed by a settings chip that opens the
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
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: pinned.length + 1,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) {
          if (index == pinned.length) {
            return const _CategorySettingsChip();
          }
          return _CategoryChip(
            category: pinned[index],
            selected: selected == pinned[index].label,
          );
        },
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return FilterChip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      elevation: 2,
      visualDensity: VisualDensity.comfortable,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      avatar: Icon(
        categoryIcon(category.id),
        size: 18,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      label: Text(category.label),
      selected: selected,
      showCheckmark: false,
      onSelected: (bool value) => unawaited(
        ref.read(commandRegistryProvider).dispatch(
          'search.category',
          <String, Object?>{'name': value ? category.id : null},
        ),
      ),
    );
  }
}

/// The trailing settings chip: opens the category picker.
class _CategorySettingsChip extends StatelessWidget {
  const _CategorySettingsChip();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Choose categories',
      child: Material(
        color: scheme.surface,
        elevation: 2,
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(showCategoryPicker(context)),
          child: SizedBox(
            width: 40,
            child: Center(
              child: Icon(
                Icons.settings,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
