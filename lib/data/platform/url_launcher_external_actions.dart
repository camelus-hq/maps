import 'package:url_launcher/url_launcher.dart';

import '../../domain/ports/external_actions.dart';

/// [ExternalActions] backed by `url_launcher`.
///
/// Every value comes from OpenStreetMap tags (hostile input), so each one is
/// validated before it reaches a platform intent and every launch is wrapped:
/// a missing dialler or a refused scheme returns `false` instead of throwing.
class UrlLauncherExternalActions implements ExternalActions {
  const UrlLauncherExternalActions();

  /// A dialable number: an optional leading `+`, then digits with the usual
  /// separators. Anything else is refused.
  static final RegExp _dialable = RegExp(r'^\+?[0-9][0-9 ()./\-]{1,30}$');

  /// A loose e-mail shape — enough to build a sane `mailto:`.
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  Future<bool> call(String phone) async {
    final String value = phone.trim();
    if (!_dialable.hasMatch(value)) {
      return false;
    }
    // Keep `+` (international) and digits; drop spaces, dashes, brackets.
    final String number = value.replaceAll(RegExp(r'[^0-9+]'), '');
    if (number.length < 3) {
      return false;
    }
    return _launch(Uri(scheme: 'tel', path: number));
  }

  @override
  Future<bool> email(String address, {String? subject}) async {
    final String value = address.trim();
    if (!_email.hasMatch(value)) {
      return false;
    }
    final String? trimmedSubject = subject?.trim();
    return _launch(
      Uri(
        scheme: 'mailto',
        path: value,
        queryParameters: (trimmedSubject == null || trimmedSubject.isEmpty)
            ? null
            : <String, String>{'subject': trimmedSubject},
      ),
    );
  }

  @override
  Future<bool> openWebsite(String url) async {
    final String value = url.trim();
    if (value.isEmpty || value.length > 2048) {
      return false;
    }
    Uri? uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) {
      // OSM often stores a bare host (`instagram.com`, `www.example.org`).
      uri = Uri.tryParse('https://$value');
    }
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }
    if (uri.host.isEmpty) {
      return false;
    }
    return _launch(uri);
  }

  Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No handler / refused scheme: the caller shows a gentle message.
      return false;
    }
  }
}
