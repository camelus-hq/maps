package app.camelus.maps

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.graphics.drawable.IconCompat

/**
 * Builds the ongoing navigation notice.
 *
 * Shared by [MainActivity] (which updates its content on every guidance change)
 * and [NavigationForegroundService] (which posts it as its **foreground**
 * notification). One builder means the notice the user sees *is* the foreground
 * service's notification — no second, hidden notification — and it carries the
 * Android 16 Live Update pieces: the player-style progress bar, an "Exit
 * navigation" action, and the status-bar chip's short text
 * (`setShortCriticalText` / `setRequestPromotedOngoing`).
 */
object NavigationNotice {
    const val CHANNEL_ID = "openmaps.navigation"
    const val NOTIFICATION_ID = 7102
    const val ACTION_EXIT_NAVIGATION = "app.camelus.maps.EXIT_NAVIGATION"

    const val EXTRA_TITLE = "title"
    const val EXTRA_BODY = "body"
    const val EXTRA_PROGRESS = "progress"
    const val EXTRA_CHIP = "chip"
    const val EXTRA_MODE = "mode"

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
                "Navigation",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shown while turn-by-turn guidance is running."
            },
        )
    }

    fun build(
        context: Context,
        title: String,
        body: String,
        progress: Int?,
        chip: String?,
        mode: String?,
    ): Notification {
        val icon = smallIconFor(mode)
        val contentIntent =
            PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        val exitIntent =
            Intent(context, MainActivity::class.java).apply {
                action = ACTION_EXIT_NAVIGATION
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
        val exitPending =
            PendingIntent.getActivity(
                context,
                1,
                exitIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        val builder =
            NotificationCompat.Builder(context, CHANNEL_ID)
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
                        IconCompat.createWithResource(context, icon),
                        "Exit",
                        exitPending,
                    ).build(),
                )
        if (progress != null) {
            builder.setProgress(100, progress.coerceIn(0, 100), false)
        }
        // Android 16 Live Update: request promotion to a status chip and set its
        // short critical text. Both are no-ops below API 36.
        if (!chip.isNullOrBlank()) {
            builder.setShortCriticalText(chip)
        }
        builder.setRequestPromotedOngoing(true)
        return builder.build()
    }

    /** The monochrome mode glyph used as the notification / status-chip icon. */
    private fun smallIconFor(mode: String?): Int =
        when (mode) {
            "cycle" -> R.drawable.ic_nav_cycle
            "walk" -> R.drawable.ic_nav_walk
            "transit" -> R.drawable.ic_nav_transit
            else -> R.drawable.ic_nav_drive
        }
}
