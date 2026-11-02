import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/app_settings.dart';
import '../domain/entities/place_category.dart';
import 'ports.dart';

/// The user's app settings (units, theme), loaded from and persisted through
/// the [SettingsRepository] port.
class SettingsController extends Notifier<AppSettings> {
  bool _modified = false;

  @override
  AppSettings build() {
    unawaited(_load());
    return const AppSettings();
  }

  Future<void> _load() async {
    final AppSettings loaded = await ref
        .read(settingsRepositoryProvider)
        .load();
    // A change made before the initial load resolved wins (never clobber it).
    if (!_modified) {
      state = loaded;
    }
  }

  Future<void> setUnit(DistanceUnit unit) async {
    if (state.unit == unit) {
      return;
    }
    _modified = true;
    state = state.copyWith(unit: unit);
    await ref.read(settingsRepositoryProvider).save(state);
  }

  Future<void> setTheme(AppThemeMode theme) async {
    if (state.theme == theme) {
      return;
    }
    _modified = true;
    state = state.copyWith(theme: theme);
    await ref.read(settingsRepositoryProvider).save(state);
  }

  Future<void> setShowOsmTags(bool show) async {
    if (state.showOsmTags == show) {
      return;
    }
    _modified = true;
    state = state.copyWith(showOsmTags: show);
    await ref.read(settingsRepositoryProvider).save(state);
  }

  Future<void> setSearchBackend(SearchBackend backend) async {
    if (state.searchBackend == backend) {
      return;
    }
    _modified = true;
    state = state.copyWith(searchBackend: backend);
    await ref.read(settingsRepositoryProvider).save(state);
  }

  /// Pins the category with [id] (idempotent). Returns `false` when the pin
  /// limit is already reached, so the caller can tell the user.
  Future<bool> pinCategory(String id) async {
    final PlaceCategory? category = placeCategoryById(id);
    if (category == null) {
      return false;
    }
    final List<String> current = state.pinnedCategoryIds;
    if (current.contains(category.id)) {
      return true;
    }
    if (current.length >= maxPinnedCategories) {
      return false;
    }
    await _setPinned(<String>[...current, category.id]);
    return true;
  }

  /// Unpins the category with [id] (idempotent).
  Future<void> unpinCategory(String id) async {
    final String key = id.trim().toLowerCase();
    final List<String> current = state.pinnedCategoryIds;
    if (!current.contains(key)) {
      return;
    }
    await _setPinned(<String>[
      for (final String value in current)
        if (value != key) value,
    ]);
  }

  /// Long-press behaviour on a picker chip: pin when unpinned, unpin when
  /// already pinned. Returns which happened (or that the limit was reached).
  Future<PinResult> togglePinnedCategory(String id) async {
    final PlaceCategory? category = placeCategoryById(id);
    if (category == null) {
      return PinResult.unchanged;
    }
    if (state.pinnedCategoryIds.contains(category.id)) {
      await unpinCategory(category.id);
      return PinResult.unpinned;
    }
    final bool pinned = await pinCategory(category.id);
    return pinned ? PinResult.pinned : PinResult.limitReached;
  }

  Future<void> _setPinned(List<String> ids) async {
    _modified = true;
    state = state.copyWith(pinnedCategoryIds: List<String>.unmodifiable(ids));
    await ref.read(settingsRepositoryProvider).save(state);
  }
}

/// The outcome of a long-press on a picker chip.
enum PinResult { pinned, unpinned, limitReached, unchanged }

final NotifierProvider<SettingsController, AppSettings> settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Convenience: whether distances should be formatted in imperial units.
final Provider<bool> imperialUnitsProvider = Provider<bool>(
  (Ref ref) => ref.watch(settingsProvider).imperial,
);

/// Developer option: whether the place sheet lists every OpenStreetMap tag.
final Provider<bool> showOsmTagsProvider = Provider<bool>(
  (Ref ref) => ref.watch(settingsProvider).showOsmTags,
);

/// The selected search backend (Mapbox or OpenStreetMap); the DI layer watches
/// this to pick the concrete `SearchService`.
final Provider<SearchBackend> searchBackendProvider = Provider<SearchBackend>(
  (Ref ref) => ref.watch(settingsProvider).searchBackend,
);

/// The categories pinned to the chip row under the search bar, in order.
final Provider<List<PlaceCategory>> pinnedCategoriesProvider =
    Provider<List<PlaceCategory>>(
      (Ref ref) =>
          categoriesByIds(ref.watch(settingsProvider).pinnedCategoryIds),
    );

/// Whether the first-run onboarding has been completed (persisted).
final FutureProvider<bool> onboardingSeenProvider = FutureProvider<bool>(
  (Ref ref) => ref.watch(settingsRepositoryProvider).onboardingSeen(),
);

/// Marks the onboarding done and refreshes [onboardingSeenProvider].
final Provider<Future<void> Function(bool)> setOnboardingSeenProvider =
    Provider<Future<void> Function(bool)>(
      (Ref ref) => (bool seen) async {
        await ref.read(settingsRepositoryProvider).setOnboardingSeen(seen);
        ref.invalidate(onboardingSeenProvider);
      },
    );
