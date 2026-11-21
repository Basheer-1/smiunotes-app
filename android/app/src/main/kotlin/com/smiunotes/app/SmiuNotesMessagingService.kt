package com.smiunotes.app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Only trusted FCM-delivered account/event notifications are displayed.
 * The background notification payload is rendered by FCM itself, while this
 * service renders foreground messages. Never display when user opted out.
 */
class SmiuNotesMessagingService : FirebaseMessagingService() {
    companion object {
        const val CHANNEL_ID = "smiunotes_alerts"
        const val PREFS = "smiunotes_push"
        const val OPTED_IN = "opted_in"
        private val CATEGORIES = setOf(
            "verification", "account", "contributor", "admin",
            "updates", "community", "support"
        )

        fun createChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
                    as NotificationManager
                manager.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID, "SMIUNotes notifications",
                        NotificationManager.IMPORTANCE_DEFAULT
                    ).apply { description = "Student account and university updates" }
                )
            }
        }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        val optedIn = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(OPTED_IN, false)
        if (!optedIn) return
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED) return

        val category = message.data["category"] ?: return
        if (category !in CATEGORIES) return  // Never publish-note broadcasts.
        val notificationId = message.data["notificationId"] ?: return
        if (!Regex("^[a-fA-F0-9-]{36}$").matches(notificationId)) return

        val title = message.notification?.title?.take(100)?.trim() ?: return
        val body = message.notification?.body?.take(240)?.trim() ?: return
        if (title.isEmpty() || body.isEmpty()) return

        createChannel(this)
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pending = PendingIntent.getActivity(
            this, notificationId.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(this, CHANNEL_ID)
        else
            @Suppress("DEPRECATION") Notification.Builder(this)

        val item = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(notificationId.hashCode(), item)
    }
}
