package app.camelus.maps

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Bridges a simple `--control <port>` request for the debug control channel.
 *
 * The Android embedding only accepts Dart entrypoint args as a serializable
 * `dart_entrypoint_args` extra, which `adb` cannot set directly. This reads a
 * plain string extra instead and forwards it to Dart's `main(List<String>
 * args)` as `["--control", "<port>"]`:
 *
 *   adb shell am start -n app.camelus.maps/.MainActivity \
 *       --es openmaps.control.port 7981
 *
 * The channel is only started in debug/profile builds (see lib/main.dart), so
 * this extra has no effect in release.
 *
 * It also answers the self-updater's `openmaps/installer` channel: Dart
 * downloads an APK into the app cache and calls `installApk`, and this hands it
 * to the system package installer (a `content://` URI via FileProvider).
 */
class MainActivity : FlutterActivity() {
    override fun getDartEntrypointArgs(): MutableList<String>? {
        val port = intent?.getStringExtra(CONTROL_PORT_EXTRA)
        if (!port.isNullOrBlank()) {
            return mutableListOf("--control", port)
        }
        return super.getDartEntrypointArgs()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALLER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> installApk(call.argument("path"), result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun installApk(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank()) {
            result.error("bad_args", "Missing APK path", null)
            return
        }
        try {
            val file = File(path)
            if (!file.exists()) {
                result.error("missing_file", "The downloaded APK was not found", null)
                return
            }
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, APK_MIME_TYPE)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(null)
        } catch (error: Exception) {
            // A missing/disabled package installer must not crash the app.
            result.error("install_failed", error.message ?: "Could not open the installer", null)
        }
    }

    private companion object {
        const val CONTROL_PORT_EXTRA = "openmaps.control.port"
        const val INSTALLER_CHANNEL = "openmaps/installer"
        const val APK_MIME_TYPE = "application/vnd.android.package-archive"
    }
}
