package com.example.vibematch_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class LiveRoomForegroundService : Service() {
    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val roomName = intent?.getStringExtra(EXTRA_ROOM_NAME)?.takeIf { it.isNotBlank() } ?: "Live Room"
        val roomId = intent?.getStringExtra(EXTRA_ROOM_ID)?.takeIf { it.isNotBlank() } ?: "Vibe Match"
        startForeground(NOTIFICATION_ID, buildNotification(roomName, roomId))
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(roomName: String, roomId: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("Vibe Match live room active")
            .setContentText("$roomName • $roomId")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Live room connection",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps Vibe Match live room connection active while the room is open."
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val CHANNEL_ID = "vibematch_live_room_connection"
        const val NOTIFICATION_ID = 6922022
        const val EXTRA_ROOM_NAME = "room_name"
        const val EXTRA_ROOM_ID = "room_id"
    }
}
