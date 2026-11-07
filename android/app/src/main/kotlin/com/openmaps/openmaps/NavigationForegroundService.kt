package app.camelus.maps

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Keeps the app running as an Android **foreground** process while turn-by-turn
 * guidance is active, and posts the ongoing navigation notice as its own
 * foreground notification.
 *
 * Backgrounded apps lose live GNSS updates (the manifest only requests
 * `whileInUse` location) and cached processes are frozen, so the notice's
 * status-bar chip stopped advancing once the app left the foreground. A
 * location-typed foreground service grants continued location access and keeps
 * the process out of the frozen state, so guidance — and the chip — keep
 * updating with the app in the background.
 *
 * Started/stopped from Dart over `MainActivity`'s `openmaps/navigation` channel
 * (`show` / `dismiss`); it runs **only** while routing. [MainActivity] updates
 * the notice's content afterwards, so the visible notification stays the
 * service's foreground notification.
 */
class NavigationForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            NavigationNotice.ensureChannel(this)
            val notification =
                NavigationNotice.build(
                    context = this,
                    title = intent.getStringExtra(NavigationNotice.EXTRA_TITLE) ?: "",
                    body = intent.getStringExtra(NavigationNotice.EXTRA_BODY) ?: "",
                    progress =
                        if (intent.hasExtra(NavigationNotice.EXTRA_PROGRESS)) {
                            intent.getIntExtra(NavigationNotice.EXTRA_PROGRESS, 0)
                        } else {
                            null
                        },
                    chip = intent.getStringExtra(NavigationNotice.EXTRA_CHIP),
                    mode = intent.getStringExtra(NavigationNotice.EXTRA_MODE),
                )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NavigationNotice.NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
                )
            } else {
                startForeground(NavigationNotice.NOTIFICATION_ID, notification)
            }
        } catch (_: Exception) {
            // Missing permission / unsupported type: guidance continues while
            // the app is open, but not in the background.
            stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopForeground(Service.STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
