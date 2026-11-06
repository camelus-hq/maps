package app.camelus.maps

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.core.graphics.drawable.IconCompat
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
 * It also answers the self-updater's `openmaps/installer` channel and posts the
 * ongoing navigation notice on the `openmaps/navigation` channel. The latter is
 * built natively (rather than through `flutter_local_notifications`) so it can
 * request promotion to an Android 16 **Live Update** — the progress bar plus a
 * **status-bar chip** (`setShortCriticalText`, `setRequestPromotedOngoing`)
 * that shows the upcoming direction, with an "Exit navigation" action whose tap
 * is forwarded back to Dart as `exitNavigation`.
 */
class MainActivity : FlutterActivity() {
    private var navigationChannel: MethodChannel? = null

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
                    showNavigationNotification(
                        title = call.argument<String>("title") ?: "",
                        body = call.argument<String>("body") ?: "",
                        progress = call.argument<Int>("progress"),
                        chip = call.argument<String>("chip"),
                        mode = call.argument<String>("mode"),
                    )
                    result.success(null)
                }
                "dismiss" -> {
                    dismissNavigationNotification()
                    result.success(null)
                }
                "requestPermission" -> result.success(requestNotificationPermission())
                else -> result.notImplemented()
            }
        }
        navigationChannel = navigation
        // The app may have been cold-started by the notification's Exit action.
        handleNavigationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNavigationIntent(intent)
    }

    /** Routes the notification's "Exit navigation" tap back to Dart. */
    private fun handleNavigationIntent(intent: Intent?) {
        if (intent?.action == ACTION_EXIT_NAVIGATION) {
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
     * Posts (or replaces) the ongoing navigation notice: a progress bar for the
     * trip, an "Exit navigation" action, and — on Android 16 — a promoted Live
     * Update whose status-bar chip carries the upcoming direction ([chip]).
     */
    private fun showNavigationNotification(
        title: String,
        body: String,
        progress: Int?,
        chip: String?,
        mode: String?,
    ) {
        try {
            ensureNavigationChannel()
            val icon = smallIconFor(mode)
            val contentIntent =
                PendingIntent.getActivity(
                    this,
                    0,
                    Intent(this, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            val exitIntent =
                Intent(this, MainActivity::class.java).apply {
                    action = ACTION_EXIT_NAVIGATION
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
            val exitPending =
                PendingIntent.getActivity(
                    this,
                    1,
                    exitIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            val builder =
                NotificationCompat.Builder(this, NAVIGATION_CHANNEL_ID)
                    .setContentTitle(title)
                    .setContentText(body)
                    .setSmallIcon(icon)
                    .setOngoing(true)
                    .setAutoCancel(false)
                    .setOnlyAlertOnce(true)
                    .setShowWhen(false)
                    .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setContentIntent(contentIntent)
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    .addAction(
                        NotificationCompat.Action.Builder(
                            IconCompat.createWithResource(this, icon),
                            "Exit",
                            exitPending,
                        ).build(),
                    )
            if (progress != null) {
                builder.setProgress(100, progress.coerceIn(0, 100), false)
            }
            // Android 16 Live Update: request promotion to a status chip and set
            // its short critical text. Both are no-ops below API 36.
            if (!chip.isNullOrBlank()) {
                builder.setShortCriticalText(chip)
            }
            builder.setRequestPromotedOngoing(true)
            NotificationManagerCompat.from(this).notify(NAVIGATION_NOTIFICATION_ID, builder.build())
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS not granted; guidance continues without a notice.
        } catch (_: Exception) {
            // Any platform surprise must never crash navigation.
        }
    }

    /** The monochrome mode glyph used as the notification / status-chip icon. */
    private fun smallIconFor(mode: String?): Int =
        when (mode) {
            "cycle" -> R.drawable.ic_nav_cycle
            "walk" -> R.drawable.ic_nav_walk
            "transit" -> R.drawable.ic_nav_transit
            else -> R.drawable.ic_nav_drive
        }

    private fun dismissNavigationNotification() {
        try {
            NotificationManagerCompat.from(this).cancel(NAVIGATION_NOTIFICATION_ID)
        } catch (_: Exception) {
            // Nothing to dismiss.
        }
    }

    private fun ensureNavigationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(NAVIGATION_CHANNEL_ID) != null) {
            return
        }
        manager.createNotificationChannel(
            NotificationChannel(
                NAVIGATION_CHANNEL_ID,
                "Navigation",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shown while turn-by-turn guidance is running."
            },
        )
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
        const val NAVIGATION_CHANNEL_ID = "openmaps.navigation"
        const val NAVIGATION_NOTIFICATION_ID = 7102
        const val ACTION_EXIT_NAVIGATION = "app.camelus.maps.EXIT_NAVIGATION"
        const val REQUEST_NOTIFICATIONS = 7102
        const val APK_MIME_TYPE = "application/vnd.android.package-archive"
    }
}
