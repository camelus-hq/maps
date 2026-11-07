package app.camelus.maps

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Keeps the app running as an Android **foreground** process while a live
 * location share is active, so the share keeps publishing (and its notice keeps
 * its place in the shade) with the app backgrounded.
 *
 * Started/stopped from Dart over `MainActivity`'s `openmaps/live_share` channel;
 * runs **only** while sharing. [MainActivity] updates the notice's text
 * afterwards.
 */
class LiveShareForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            LiveShareNotice.ensureChannel(this)
            val notification =
                LiveShareNotice.build(
                    context = this,
                    title = intent.getStringExtra(LiveShareNotice.EXTRA_TITLE) ?: "",
                    body = intent.getStringExtra(LiveShareNotice.EXTRA_BODY) ?: "",
                )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    LiveShareNotice.NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
                )
            } else {
                startForeground(LiveShareNotice.NOTIFICATION_ID, notification)
            }
        } catch (_: Exception) {
            // Missing permission / unsupported type: sharing continues while the
            // app is open, but not in the background.
            stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopForeground(Service.STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
