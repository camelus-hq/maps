import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The bottom-navigation tab on the map-home shell.
enum HomeTab { explore, you, contribute }

/// Drives the map-home bottom navigation (Explore / You / Contribute).
///
/// Lives in L3 so the `app.tab` command and the UI share one path.
class HomeTabController extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.explore;

  void select(HomeTab tab) => state = tab;
}

final NotifierProvider<HomeTabController, HomeTab> homeTabProvider =
    NotifierProvider<HomeTabController, HomeTab>(HomeTabController.new);

/// The active category shown in the map-local category results sheet, or null.
///
/// Set by the place sheet's "Nearby" action (`place.nearby`); the category
/// chips under the search bar no longer use it — they open the search screen
/// with the browse results instead.
class SelectedCategoryController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? category) => state = category;
}

final NotifierProvider<SelectedCategoryController, String?>
selectedCategoryProvider =
    NotifierProvider<SelectedCategoryController, String?>(
      SelectedCategoryController.new,
    );
