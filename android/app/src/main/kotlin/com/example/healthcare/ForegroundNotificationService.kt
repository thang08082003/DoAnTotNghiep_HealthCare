package com.example.healthcare

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.google.firebase.FirebaseApp
import com.google.firebase.firestore.DocumentChange
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.auth.FirebaseAuth
import org.json.JSONObject

class ForegroundNotificationService : Service() {
    private val CHANNEL_ID = "bg_sync_channel"
    private val CHANNEL_NAME = "Background Sync"
    private val ALERT_CHANNEL_ID = "bg_alerts"
    private val ALERT_CHANNEL_NAME = "App Alerts"
    private val ONGOING_ID = 10001

    private var registration: ListenerRegistration? = null
    private var userId: String? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        userId = intent?.getStringExtra("userId")
        startForeground(ONGOING_ID, buildOngoingNotification())
        startListening()
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        registration?.remove()
        registration = null
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_LOW
                )
                channel.description = "Background notification listener"
                nm.createNotificationChannel(channel)
            }
            if (nm.getNotificationChannel(ALERT_CHANNEL_ID) == null) {
                val channelHigh = NotificationChannel(
                    ALERT_CHANNEL_ID,
                    ALERT_CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                )
                channelHigh.description = "High priority app alerts"
                nm.createNotificationChannel(channelHigh)
            }
        }
    }

    private fun buildOngoingNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Đang lắng nghe thông báo")
            .setContentText("Ứng dụng sẽ hiển thị thông báo mới")
            .setSmallIcon(android.R.drawable.stat_notify_more)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun startListening() {
    val uid = userId ?: FirebaseAuth.getInstance().currentUser?.uid ?: return
        try {
            if (FirebaseApp.getApps(this).isEmpty()) {
                FirebaseApp.initializeApp(this)
            }
        } catch (_: Exception) { }

        val db = FirebaseFirestore.getInstance()
        registration?.remove()
        registration = db.collection("notifications")
            .whereEqualTo("userId", uid)
            .whereEqualTo("isRead", false)
            .addSnapshotListener { snapshots, _ ->
                if (snapshots == null) return@addSnapshotListener
                for (dc in snapshots.documentChanges) {
                    if (dc.type == DocumentChange.Type.ADDED || dc.type == DocumentChange.Type.MODIFIED) {
                        val title = dc.document.getString("title") ?: "Thông báo"
                        val body = dc.document.getString("body") ?: ""
                        // Build payload JSON for Flutter side deep-link
                        val payloadObj = JSONObject()
                        val type = dc.document.getString("type")
                        if (type != null) payloadObj.put("type", type)
                        payloadObj.put("notificationId", dc.document.id)
                        val dataField = dc.document.get("data")
                        if (dataField is Map<*, *>) {
                            try {
                                payloadObj.put("data", JSONObject(dataField))
                            } catch (_: Exception) { }
                        }
                        showOneShot(title, body, payloadObj.toString())
                    }
                }
            }
    }

    private fun showOneShot(title: String, body: String, payload: String? = null) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val id = (System.currentTimeMillis() % Int.MAX_VALUE).toInt()
        val intent = Intent(this, MainActivity::class.java)
        if (!payload.isNullOrEmpty()) {
            intent.putExtra("payload", payload)
        }
        val tapIntent = PendingIntent.getActivity(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )
        val builder = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_chat)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(tapIntent)
        manager.notify(id, builder.build())
    }
}
