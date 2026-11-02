/// Hands a place's contact details to the device's own apps: dial a phone
/// number, compose an e-mail, or open a website.
///
/// A thin port (AGENTS.md §Architecture) so the presentation/state layers never
/// depend on a specific launcher package directly; the keyless/test default is
/// [FakeExternalActions] and `lib/app/di.dart` wires the real one.
abstract interface class ExternalActions {
  /// Opens the dialler on [phone] (a `tel:` URI). Returns `false` when the
  /// number is unusable or no dialler is available.
  Future<bool> call(String phone);

  /// Opens the mail composer for [address], optionally prefilled with
  /// [subject]. Returns `false` when the address is unusable.
  Future<bool> email(String address, {String? subject});

  /// Opens [url] in the browser. A bare host (`instagram.com`) is treated as
  /// `https://`. Returns `false` for anything that is not http(s).
  Future<bool> openWebsite(String url);
}
