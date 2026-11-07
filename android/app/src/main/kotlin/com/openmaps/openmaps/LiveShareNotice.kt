package app.camelus.maps

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * Builds the ongoing "sharing your live location" notice.
 *
 * Shared by [MainActivity] (which updates its text on every publish) and
 * [LiveShareForegroundService] (which posts it as its **foreground**
 * notification), so the notice the user sees is the foreground service's
 * notification — no second, hidden one.
 */
object LiveShareNotice {
    const val CHANNEL_ID = "openmaps.live_share"
    const val NOTIFICATION_ID = 7101

    const val EXTRA_TITLE = "title"
    const val EXTRA_BODY = "body"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) {
            return
        }
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Live location sharing",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shown while your live location is shared with friends."
            },
        )
    }

    fun build(
        context: Context,
        title: String,
        body: String,
    ): Notification {
        val contentIntent =
            PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory("location_sharing")
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(contentIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
