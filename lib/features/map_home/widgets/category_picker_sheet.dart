import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/place_category.dart';
import '../../../state/commands/commands_provider.dart';
import '../../../state/settings.dart';
import 'category_icons.dart';

/// Presents the category picker: every browse category, grouped, with the
/// pinned ones highlighted.
Future<void> showCategoryPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => const CategoryPickerSheet(),
  );
}

/// A scrollable grid of browse-category chips grouped like the OpenStreetMap
/// wiki's `Key:amenity` sections.
///
/// * **Short press** runs the category browse (opens the search screen).
/// * **Long press** pins the category to the chip row under the search bar (or
///   unpins it), up to [maxPinnedCategories].
class CategoryPickerSheet extends ConsumerWidget {
  const CategoryPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String> pinned = ref.watch(settingsProvider).pinnedCategoryIds;
    final Set<String> pinnedSet = pinned.toSet();
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Choose categories',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Tap to search nearby · long press to pin to the top '
                    '(${pinned.length}/$maxPinnedCategories)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                children: <Widget>[
                  for (final String group in categoryGroups)
                    _group(context, ref, group, pinnedSet),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _group(
    BuildContext context,
    WidgetRef ref,
    String group,
    Set<String> pinned,
  ) {
    final List<PlaceCategory> categories = <PlaceCategory>[
      for (final PlaceCategory category in placeCategories)
        if (category.group == group) category,
    ];
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.xs,
          ),
          child: Text(group, style: Theme.of(context).textTheme.titleMedium),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final PlaceCategory category in categories)
              _chip(context, ref, category, pinned.contains(category.id)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _chip(
    BuildContext context,
    WidgetRef ref,
    PlaceCategory category,
    bool pinned,
  ) {
    return GestureDetector(
      onLongPress: () => unawaited(_togglePin(context, ref, category)),
      child: FilterChip(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.comfortable,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        avatar: Icon(categoryIcon(category.id), size: 18),
        label: Text(category.label),
        selected: pinned,
        showCheckmark: false,
        onSelected: (_) => _search(context, ref, category),
      ),
    );
  }

  Future<void> _togglePin(
    BuildContext context,
    WidgetRef ref,
    PlaceCategory category,
  ) async {
    final PinResult result = await ref
        .read(settingsProvider.notifier)
        .togglePinnedCategory(category.id);
    if (!context.mounted) {
      return;
    }
    final String? message = switch (result) {
      PinResult.limitReached =>
        'You can pin up to $maxPinnedCategories categories',
      PinResult.pinned => '${category.label} pinned',
      PinResult.unpinned => '${category.label} unpinned',
      PinResult.unchanged => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  /// Short press: browse the category (the chip-row behaviour) and open the
  /// search screen with the results. Closes the sheet first so the picker does
  /// not sit under the search screen.
  void _search(BuildContext context, WidgetRef ref, PlaceCategory category) {
    final registry = ref.read(commandRegistryProvider);
    Navigator.of(context).maybePop();
    unawaited(
      registry.dispatch('search.category', <String, Object?>{
        'name': category.id,
      }),
    );
  }
}
