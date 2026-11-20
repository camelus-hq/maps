package app.camelus.maps.openmaps_notifications

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Shows OpenMaps' incoming-push notifications.
///
/// Registered as a plugin so it is present on the background Flutter engine that
/// `firebase_messaging` starts for data-only messages, which is where the gift
/// wrap is decrypted. The small icon is a system drawable: a plugin cannot use
/// the host app's resources, and a notification without an icon is dropped.
class OpenmapsNotificationsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "show" -> {
                show(
                    id = call.argument<Int>("id") ?: 0,
                    title = call.argument<String>("title") ?: "",
                    body = call.argument<String>("body") ?: "",
                    groupKey = call.argument<String>("groupKey"),
                )
                result.success(null)
            }
            "cancel" -> {
                NotificationManagerCompat.from(context)
                    .cancel(call.argument<Int>("id") ?: 0)
                result.success(null)
            }
            "requestPermission" -> result.success(hasPermission())
            else -> result.notImplemented()
        }
    }

    private fun hasPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun show(id: Int, title: String, body: String, groupKey: String?) {
        if (!hasPermission()) {
            return
        }
        ensureChannel()
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
        if (groupKey != null) {
            builder.setGroup(groupKey)
        }
        try {
            NotificationManagerCompat.from(context).notify(id, builder.build())
        } catch (_: SecurityException) {
            // Permission was revoked between the check and the post.
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) {
            return
        }
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "OpenMaps notifications",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = "Live shares, messages and other activity" },
        )
    }

    private companion object {
        const val CHANNEL_NAME = "openmaps/push_notifications"
        const val CHANNEL_ID = "openmaps_push"
    }
}
