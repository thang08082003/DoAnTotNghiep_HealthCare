package com.example.healthcare

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.OxygenSaturationRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.Timestamp
import kotlinx.coroutines.tasks.await
import java.time.Instant
import java.util.Date
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * Worker that drains recent data from Health Connect and uploads to Firestore.
 * For simplicity, it reads last 2 hours and writes idempotently by startTime epoch millis as doc id.
 */
class PassiveDrainWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        val TAG = "HC_DRAIN"
        Log.i(TAG, "doWork(): start")
        try {
            // Ensure Firebase initialized
            if (FirebaseApp.getApps(applicationContext).isEmpty()) {
                FirebaseApp.initializeApp(applicationContext)
            }
            val uid = FirebaseAuth.getInstance().currentUser?.uid
            if (uid == null) {
                Log.w(TAG, "doWork(): no Firebase user, skip")
                return Result.success()
            }

            val client = HealthConnectClient.getOrCreate(applicationContext)
            // Confirm permissions
            val need = setOf(
                HealthPermission.getReadPermission(HeartRateRecord::class),
                HealthPermission.getReadPermission(OxygenSaturationRecord::class),
                HealthPermission.getReadPermission(SleepSessionRecord::class)
            )
            val granted = client.permissionController.getGrantedPermissions()
            val hasAll = need.all { it in granted }
            Log.i(TAG, "doWork(): granted=${granted.size}, hasAll=$hasAll")
            if (!hasAll) return Result.success()

            val now = ZonedDateTime.now(ZoneId.systemDefault()).toInstant()
            val start = now.minusSeconds(2 * 3600) // last 2 hours

            val db = FirebaseFirestore.getInstance()

            // Heart rate (use the latest sample time for ts; auto-ID docs)
            try {
                val hr = client.readRecords(ReadRecordsRequest(HeartRateRecord::class, timeRangeFilter = TimeRangeFilter.between(start, now))).records
                Log.i(TAG, "doWork(): heartRate records=${hr.size}")
                for (r in hr) {
                    val sample = r.samples.maxByOrNull { it.time } ?: r.samples.lastOrNull()
                    val bpm = sample?.beatsPerMinute ?: 0.0
                    val tsMillis = sample?.time?.toEpochMilli() ?: r.endTime.toEpochMilli()
                    val metaId = r.metadata.id ?: ""
                    val map = hashMapOf(
                        "bpm" to bpm,
                        "ts" to Timestamp(Date(tsMillis)),
                        "source" to (r.metadata.dataOrigin.packageName ?: "health_connect"),
                        "metaId" to metaId
                    )
                    db.collection("users").document(uid).collection("heart_rate").add(map)
                }
            } catch (_: Exception) {}

            // SpO2 (auto-ID docs)
            try {
                val spo2 = client.readRecords(ReadRecordsRequest(OxygenSaturationRecord::class, timeRangeFilter = TimeRangeFilter.between(start, now))).records
                Log.i(TAG, "doWork(): spo2 records=${spo2.size}")
                for (r in spo2) {
                    val tsMillis = r.time.toEpochMilli()
                    val metaId = r.metadata.id ?: ""
                    val map = hashMapOf(
                        "percentage" to r.percentage.value,
                        "ts" to Timestamp(Date(tsMillis)),
                        "source" to (r.metadata.dataOrigin.packageName ?: "health_connect"),
                        "metaId" to metaId
                    )
                    db.collection("users").document(uid).collection("spo2").add(map)
                }
            } catch (_: Exception) {}

            // Sleep sessions (auto-ID docs)
            try {
                val sleep = client.readRecords(ReadRecordsRequest(SleepSessionRecord::class, timeRangeFilter = TimeRangeFilter.between(start, now))).records
                Log.i(TAG, "doWork(): sleep sessions=${sleep.size}")
                for (r in sleep) {
                    val startTs = r.startTime.toEpochMilli()
                    val endTs = r.endTime.toEpochMilli()
                    val durationMinutes = ((endTs - startTs) / 60000L).toInt()
                    val metaId = r.metadata.id ?: ""
                    val map = hashMapOf(
                        "start" to Timestamp(Date(startTs)),
                        "end" to Timestamp(Date(endTs)),
                        "durationMinutes" to durationMinutes,
                        "title" to (r.title ?: ""),
                        "source" to (r.metadata.dataOrigin.packageName ?: "health_connect"),
                        "metaId" to metaId
                    )
                    db.collection("users").document(uid).collection("sleep_sessions").add(map)
                }
            } catch (_: Exception) {}

            // After uploading data, trigger AI health monitoring if conditions met
            try {
                triggerHealthMonitoring(applicationContext, uid)
            } catch (e: Exception) {
                Log.w(TAG, "doWork(): health monitoring check failed", e)
            }

            Log.i(TAG, "doWork(): success")
            return Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "doWork(): error", e)
            return Result.retry()
        }
    }

    private suspend fun triggerHealthMonitoring(context: Context, userId: String) {
        // Check if enough time passed since last monitoring (6 hours minimum)
        val prefs = context.getSharedPreferences("health_monitoring", Context.MODE_PRIVATE)
        val lastCheck = prefs.getLong("last_monitoring_$userId", 0)
        val now = System.currentTimeMillis()
        val sixHoursMs = 6 * 60 * 60 * 1000L
        
        if (now - lastCheck < sixHoursMs) {
            Log.i("HC_DRAIN", "triggerHealthMonitoring: skipping, last check was ${(now - lastCheck) / 60000} minutes ago")
            return
        }
        
        // Update last check time
        prefs.edit().putLong("last_monitoring_$userId", now).apply()
        
        // Call Flutter method to run monitoring
        // This will be handled by MethodChannel in MainActivity
        val intent = android.content.Intent("com.example.healthcare.RUN_HEALTH_MONITORING")
        intent.putExtra("userId", userId)
        context.sendBroadcast(intent)
        
        Log.i("HC_DRAIN", "triggerHealthMonitoring: broadcast sent for user $userId")
    }
}
