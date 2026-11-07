package app.camelus.maps

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
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
 * It also answers the self-updater's `openmaps/installer` channel and posts the
 * two ongoing notices — the running trip (`openmaps/navigation`) and the live
 * location share (`openmaps/live_share`). Both notices are **foreground
 * service** notifications ([NavigationForegroundService],
 * [LiveShareForegroundService]) so the process stays out of the OS's
 * cached/frozen state and keeps receiving GNSS updates with the app
 * backgrounded; the notice the user sees *is* the service's notification.
 */
class MainActivity : FlutterActivity() {
    private var navigationChannel: MethodChannel? = null
    private var navigationForegroundActive = false
    private var liveShareForegroundActive = false

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

        val navigation =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL)
        navigation.setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    showNavigationNotice(call)
                    result.success(null)
                }
                "dismiss" -> {
                    stopNavigation()
                    result.success(null)
                }
                "requestPermission" -> result.success(requestNotificationPermission())
                else -> result.notImplemented()
            }
        }
        navigationChannel = navigation

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIVE_SHARE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> {
                        showLiveShareNotice(call)
                        result.success(null)
                    }
                    "dismiss" -> {
                        stopLiveShare()
                        result.success(null)
                    }
                    "requestPermission" -> result.success(requestNotificationPermission())
                    else -> result.notImplemented()
                }
            }

        // The app may have been cold-started by the notification's Exit action.
        handleNavigationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNavigationIntent(intent)
    }

    override fun onDestroy() {
        // The Flutter engine (and its Dart state) dies with the activity, so a
        // backgrounded foreground service would otherwise linger as a stale
        // notice. Stopping it here removes the notice when the app is closed or
        // swiped away. Backgrounding with Home does not destroy the activity, so
        // guidance/sharing keep running there.
        stopNavigation()
        stopLiveShare()
        super.onDestroy()
    }

    /** Routes the notification's "Exit navigation" tap back to Dart. */
    private fun handleNavigationIntent(intent: Intent?) {
        if (intent?.action == NavigationNotice.ACTION_EXIT_NAVIGATION) {
            // Consume it so a later recreation does not re-fire the action.
            intent.action = null
            navigationChannel?.invokeMethod("exitNavigation", null)
        }
    }

    /** Asks for POST_NOTIFICATIONS (Android 13+); true when already granted. */
    private fun requestNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }
        val granted =
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        if (granted) {
            return true
        }
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_NOTIFICATIONS,
        )
        return false
    }

    /**
     * Posts (or replaces) the ongoing navigation notice and, on the first call,
     * starts [NavigationForegroundService] so the notice is a foreground
     * notification and the process keeps receiving position updates in the
     * background.
     */
    private fun showNavigationNotice(call: MethodCall) {
        val title = call.argument<String>("title") ?: ""
        val body = call.argument<String>("body") ?: ""
        val progress = call.argument<Int>("progress")
        val chip = call.argument<String>("chip")
        val mode = call.argument<String>("mode")
        try {
            NavigationNotice.ensureChannel(this)
            if (!navigationForegroundActive) {
                navigationForegroundActive = true
                // Started from the foreground (guidance is started from the
                // visible app). The service builds the notice from these extras
                // and posts it as its foreground notification; a later update
                // below just replaces its content.
                ContextCompat.startForegroundService(
                    this,
                    Intent(this, NavigationForegroundService::class.java).apply {
                        putExtra(NavigationNotice.EXTRA_TITLE, title)
                        putExtra(NavigationNotice.EXTRA_BODY, body)
                        if (progress != null) {
                            putExtra(NavigationNotice.EXTRA_PROGRESS, progress)
                        }
                        putExtra(NavigationNotice.EXTRA_CHIP, chip)
                        putExtra(NavigationNotice.EXTRA_MODE, mode)
                    },
                )
            }
            NotificationManagerCompat.from(this).notify(
                NavigationNotice.NOTIFICATION_ID,
                NavigationNotice.build(this, title, body, progress, chip, mode),
            )
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS not granted; guidance continues without a notice.
        } catch (_: Exception) {
            // A background-start rejection / platform surprise must never crash
            // navigation.
            navigationForegroundActive = false
        }
    }

    private fun stopNavigation() {
        navigationForegroundActive = false
        try {
            stopService(Intent(this, NavigationForegroundService::class.java))
        } catch (_: Exception) {
            // Nothing to stop.
        }
        try {
            NotificationManagerCompat.from(this).cancel(NavigationNotice.NOTIFICATION_ID)
        } catch (_: Exception) {
            // Nothing to dismiss.
        }
    }

    /**
     * Posts (or replaces) the ongoing live-share notice and, on the first call,
     * starts [LiveShareForegroundService] so the process keeps publishing
     * location with the app backgrounded.
     */
    private fun showLiveShareNotice(call: MethodCall) {
        val title = call.argument<String>("title") ?: ""
        val body = call.argument<String>("body") ?: ""
        try {
            LiveShareNotice.ensureChannel(this)
            if (!liveShareForegroundActive) {
                liveShareForegroundActive = true
                ContextCompat.startForegroundService(
                    this,
                    Intent(this, LiveShareForegroundService::class.java).apply {
                        putExtra(LiveShareNotice.EXTRA_TITLE, title)
                        putExtra(LiveShareNotice.EXTRA_BODY, body)
                    },
                )
            }
            NotificationManagerCompat.from(this).notify(
                LiveShareNotice.NOTIFICATION_ID,
                LiveShareNotice.build(this, title, body),
            )
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS not granted; sharing continues without a notice.
        } catch (_: Exception) {
            liveShareForegroundActive = false
        }
    }

    private fun stopLiveShare() {
        liveShareForegroundActive = false
        try {
            stopService(Intent(this, LiveShareForegroundService::class.java))
        } catch (_: Exception) {
            // Nothing to stop.
        }
        try {
            NotificationManagerCompat.from(this).cancel(LiveShareNotice.NOTIFICATION_ID)
        } catch (_: Exception) {
            // Nothing to dismiss.
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
            val intent =
                Intent(Intent.ACTION_VIEW).apply {
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
        const val NAVIGATION_CHANNEL = "openmaps/navigation"
        const val LIVE_SHARE_CHANNEL = "openmaps/live_share"
        const val REQUEST_NOTIFICATIONS = 7102
        const val APK_MIME_TYPE = "application/vnd.android.package-archive"
    }
}
