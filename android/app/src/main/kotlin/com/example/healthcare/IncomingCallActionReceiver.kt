package com.example.healthcare

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.FirebaseApp
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore

class IncomingCallActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_ACCEPT = "com.example.healthcare.ACTION_ACCEPT_CALL"
        const val ACTION_DECLINE = "com.example.healthcare.ACTION_DECLINE_CALL"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val callId = intent.getStringExtra("callId") ?: return
        val db = try {
            if (FirebaseApp.getApps(context).isEmpty()) {
                FirebaseApp.initializeApp(context)
            }
            FirebaseFirestore.getInstance()
        } catch (e: Exception) {
            FirebaseFirestore.getInstance()
        }

        when (action) {
            ACTION_ACCEPT -> {
                db.collection("call_sessions").document(callId)
                    .update(mapOf(
                        "status" to "accepted",
                        "updatedAt" to FieldValue.serverTimestamp()
                    ))
                // Clean related incoming_call notifications in Firestore (async)
                db.collection("notifications")
                    .whereEqualTo("type", "incoming_call")
                    .whereEqualTo("data.callId", callId)
                    .get()
                    .addOnSuccessListener { snap ->
                        val batch = db.batch()
                        for (d in snap.documents) batch.delete(d.reference)
                        batch.commit()
                    }
                // Bring app to foreground to show call UI
                val channelName = intent.getStringExtra("channelName") ?: ""
                val callerName = intent.getStringExtra("callerName") ?: "Người gọi"
                val payload = "{" +
                    "\"type\":\"incoming_call\"," +
                    "\"callId\":\"$callId\"," +
                    "\"channelName\":\"$channelName\"," +
                    "\"callerName\":\"$callerName\"}" 
                val launch = Intent(context, MainActivity::class.java)
                launch.putExtra("payload", payload)
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                context.startActivity(launch)
                // Cancel the notification too
                val nm = NotificationManagerCompat.from(context)
                val id = (callId.hashCode() and 0x7fffffff) % 100000000
                nm.cancel(id)
            }
            ACTION_DECLINE -> {
                db.collection("call_sessions").document(callId)
                    .update(mapOf(
                        "status" to "declined",
                        "updatedAt" to FieldValue.serverTimestamp()
                    ))
                // Clean related incoming_call notifications in Firestore (async)
                db.collection("notifications")
                    .whereEqualTo("type", "incoming_call")
                    .whereEqualTo("data.callId", callId)
                    .get()
                    .addOnSuccessListener { snap ->
                        val batch = db.batch()
                        for (d in snap.documents) batch.delete(d.reference)
                        batch.commit()
                    }
                // Cancel the notification
                val nm = NotificationManagerCompat.from(context)
                val id = (callId.hashCode() and 0x7fffffff) % 100000000
                nm.cancel(id)
                
                // Open app but do NOT join the call
                val launch = Intent(context, MainActivity::class.java)
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                context.startActivity(launch)
            }
        }
    }
}
