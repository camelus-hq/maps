import 'place.dart';

/// One entry in the search screen's recent list.
///
/// A recent search is either a **place** the user opened or navigated to
/// ([RecentPlaceSearch]) or a **text query** they submitted ([RecentTextSearch]).
/// The reference shows both kinds together — a place leads with its category
/// glyph while a typed query leads with a clock — so the two are modelled as one
/// ordered list.
sealed class RecentSearch {
  const RecentSearch();

  /// A stable key used to de-duplicate the list: recording an entry that is
  /// already present moves it back to the top instead of adding a second row.
  String get key;
}

/// A place the user viewed or navigated to.
final class RecentPlaceSearch extends RecentSearch {
  const RecentPlaceSearch(this.place);

  final Place place;

  @override
  String get key => 'place:${place.id}';
}

/// A query the user typed and submitted.
final class RecentTextSearch extends RecentSearch {
  const RecentTextSearch(this.text);

  final String text;

  @override
  String get key => 'query:${text.toLowerCase()}';
}
