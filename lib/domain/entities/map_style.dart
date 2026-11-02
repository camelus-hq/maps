/// Base map styles offered by the layers switcher.
///
/// The concrete style URLs are a data-layer concern (see
/// `lib/data/mapbox/`), so the domain only names the user-facing choices.
/// "Traffic" is a separate overlay toggle, not a base style.
enum BaseMapStyle { standard, satellite, terrain }
