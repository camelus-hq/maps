import '../../domain/entities/place_category.dart';

/// Maps our browse-category ids to an **Overpass QL** tag filter.
///
/// The filter is the bracket *body* only (e.g. `"amenity"="cafe"` or a regex
/// match), so the query builder wraps it once per element type. The category's
/// OpenStreetMap tagging comes from the domain catalogue
/// ([placeCategories]); `null` means the id is not a category we browse, so the
/// caller can fall back to a free-text search.
abstract final class OsmCategoryFilter {
  /// The Overpass tag filter for [categoryId], or `null` when unknown.
  static String? forCategory(String categoryId) {
    final PlaceCategory? category = placeCategoryById(categoryId);
    if (category == null) {
      return null;
    }
    final List<String> values = category.osmValueList;
    if (values.length == 1) {
      return '"${category.osmKey}"="${values.single}"';
    }
    return '"${category.osmKey}"~"^(${values.join('|')})\$"';
  }
}
