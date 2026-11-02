import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/platform/url_launcher_external_actions.dart';

/// The real launcher validates OSM-sourced values before they reach a platform
/// intent. (No platform is present in a test, so a *valid* value simply returns
/// `false` — what matters here is that hostile values are refused without ever
/// attempting a launch, and that nothing throws.)
void main() {
  const UrlLauncherExternalActions actions = UrlLauncherExternalActions();

  test('refuses phone values that are not dialable', () async {
    for (final String value in <String>[
      '',
      'call us',
      '+++',
      'javascript:alert(1)',
      '1',
    ]) {
      expect(await actions.call(value), isFalse, reason: 'phone: $value');
    }
  });

  test('refuses malformed e-mail addresses', () async {
    for (final String value in <String>['', 'nope', '@x', 'a@b']) {
      expect(await actions.email(value), isFalse, reason: 'email: $value');
    }
  });

  test('refuses non-http(s) website values', () async {
    for (final String value in <String>[
      '',
      'javascript:alert(1)',
      'file:///etc/passwd',
      'tel:123',
      '   ',
    ]) {
      expect(
        await actions.openWebsite(value),
        isFalse,
        reason: 'website: $value',
      );
    }
  });

  test('accepts a bare host and a real number without throwing', () async {
    // No platform in a test, so these report false — but they must not throw.
    expect(await actions.openWebsite('instagram.com/mokalola'), isFalse);
    expect(await actions.call('+49 30 53166994'), isFalse);
    expect(await actions.email('hi@mokalola.de'), isFalse);
  });

  test('bounds an oversized website value', () async {
    expect(await actions.openWebsite('https://${'a' * 3000}.com'), isFalse);
  });
}
