import 'dart:io';

/// Captures a PNG of the running app for `openmaps_screenshot`.
abstract interface class ScreenshotSource {
  /// Raw PNG bytes, or `null` when this source cannot capture (caller falls
  /// back to the control channel's `ui.screenshot`).
  Future<List<int>?> capture();
}

/// Captures the emulator/device screen with adb, which (unlike the in-app
/// `ui.screenshot`) includes the Mapbox platform view.
class AdbScreenshotSource implements ScreenshotSource {
  AdbScreenshotSource({this.serial});

  /// Optional adb device serial (`-s <serial>`) when several are attached.
  final String? serial;

  @override
  Future<List<int>?> capture() async {
    try {
      final ProcessResult result = await Process.run('adb', <String>[
        if (serial != null) ...<String>['-s', serial!],
        'exec-out',
        'screencap',
        '-p',
      ], stdoutEncoding: null).timeout(const Duration(seconds: 20));
      if (result.exitCode != 0) {
        return null;
      }
      final Object? out = result.stdout;
      return out is List<int> ? out : null;
    } catch (_) {
      return null;
    }
  }
}

/// A source that never captures — used when only the app-window screenshot is
/// available, or in tests.
class NoScreenshotSource implements ScreenshotSource {
  const NoScreenshotSource();

  @override
  Future<List<int>?> capture() async => null;
}
