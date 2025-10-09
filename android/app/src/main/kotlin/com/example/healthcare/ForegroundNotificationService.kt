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
    private val CALL_CHANNEL_ID = "incoming_call_channel"
    private val CALL_CHANNEL_NAME = "Incoming Calls"
    private val ONGOING_ID = 10001

    private var registration: ListenerRegistration? = null
    private var callRegistration: ListenerRegistration? = null
    private var userId: String? = null
    private val callNotifIds = HashMap<String, Int>()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    

    override fun onDestroy() {
        super.onDestroy()
        registration?.remove()
        registration = null
        callRegistration?.remove()
        callRegistration = null
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
            if (nm.getNotificationChannel(CALL_CHANNEL_ID) == null) {
                val callChannel = NotificationChannel(
                    CALL_CHANNEL_ID,
                    CALL_CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                )
                callChannel.description = "Incoming call alerts"
                nm.createNotificationChannel(callChannel)
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

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        userId = intent?.getStringExtra("userId")
        startForeground(ONGOING_ID, buildOngoingNotification())
        startListening()
        startListeningIncomingCalls()
        return START_STICKY
    }

    private fun startListeningIncomingCalls() {
        val uid = userId ?: FirebaseAuth.getInstance().currentUser?.uid ?: return
        try {
            if (FirebaseApp.getApps(this).isEmpty()) {
                FirebaseApp.initializeApp(this)
            }
        } catch (_: Exception) { }

        val db = FirebaseFirestore.getInstance()
        callRegistration?.remove()
        callRegistration = db.collection("call_sessions")
            .whereEqualTo("calleeId", uid)
            .whereEqualTo("status", "ringing")
            .addSnapshotListener { snapshots, _ ->
                if (snapshots == null) return@addSnapshotListener
                for (dc in snapshots.documentChanges) {
                    val doc = dc.document
                    val callId = doc.id
                    when (dc.type) {
                        DocumentChange.Type.ADDED -> {
                            val callerId = doc.getString("callerId") ?: ""
                            val channelName = doc.getString("channelName") ?: ""
                            // Try to fetch caller name
                            FirebaseFirestore.getInstance().collection("users")
                                .document(callerId)
                                .get()
                                .addOnSuccessListener { udoc ->
                                    val callerName = udoc.getString("name") ?: callerId
                                    showIncomingCall(callId, callerId, callerName, channelName)
                                }
                                .addOnFailureListener { _ ->
                                    showIncomingCall(callId, callerId, callerId, channelName)
                                }
                        }
                        DocumentChange.Type.REMOVED -> {
                            // Status changed away from ringing
                            cancelIncomingCallNotification(callId)
                        }
                        else -> {}
                    }
                }
            }
    }

    private fun showIncomingCall(callId: String, callerId: String, callerName: String, channelName: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notifId = (callId.hashCode() and 0x7fffffff) % 100000000
        callNotifIds[callId] = notifId

        val payloadObj = JSONObject()
        payloadObj.put("type", "incoming_call")
        payloadObj.put("callId", callId)
        payloadObj.put("channelName", channelName)
        payloadObj.put("callerId", callerId)
        payloadObj.put("callerName", callerName)
    payloadObj.put("origin", "native")

        val fullIntent = Intent(this, MainActivity::class.java).apply {
            putExtra("payload", payloadObj.toString())
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val fullPending = PendingIntent.getActivity(
            this,
            notifId,
            fullIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val builder = NotificationCompat.Builder(this, CALL_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_phone_call)
            .setContentTitle("Cuộc gọi đến")
            .setContentText("Từ $callerName")
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(fullPending, true)
            .setContentIntent(fullPending)

        manager.notify(notifId, builder.build())
    }

    private fun cancelIncomingCallNotification(callId: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val id = callNotifIds.remove(callId) ?: ((callId.hashCode() and 0x7fffffff) % 100000000)
        manager.cancel(id)
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
