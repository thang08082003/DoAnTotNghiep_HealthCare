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
import com.google.firebase.firestore.FieldValue
import kotlinx.coroutines.tasks.await
import java.time.Instant
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

            // Heart rate (use the latest sample time for ts; decouple doc id from ts)
            try {
                val hr = client.readRecords(ReadRecordsRequest(HeartRateRecord::class, timeRangeFilter = TimeRangeFilter.between(start, now))).records
                Log.i(TAG, "doWork(): heartRate records=${hr.size}")
                for (r in hr) {
                    val sample = r.samples.maxByOrNull { it.time } ?: r.samples.lastOrNull()
                    val bpm = sample?.beatsPerMinute ?: 0.0
                    val tsMillis = sample?.time?.toEpochMilli() ?: r.endTime.toEpochMilli()
                    val baseId = r.metadata.id ?: "hr"
                    val docId = "${baseId}_${tsMillis}"
                    val map = hashMapOf(
                        "bpm" to bpm,
                        "ts" to tsMillis,
                        "source" to (r.metadata.dataOrigin.packageName ?: "health_connect"),
                        "createdAt" to FieldValue.serverTimestamp()
                    )
                    db.collection("users").document(uid).collection("heart_rate").document(docId).set(map)
                }
            } catch (_: Exception) {}

            // SpO2 (doc id decoupled from ts to avoid id==ts)
            try {
                val spo2 = client.readRecords(ReadRecordsRequest(OxygenSaturationRecord::class, timeRangeFilter = TimeRangeFilter.between(start, now))).records
                Log.i(TAG, "doWork(): spo2 records=${spo2.size}")
                for (r in spo2) {
                    val tsMillis = r.time.toEpochMilli()
                    val baseId = r.metadata.id ?: "spo2"
                    val id = "${baseId}_${tsMillis}"
                    val map = hashMapOf(
                        "pct" to r.percentage.value,
                        "ts" to r.time.toEpochMilli(),
                        "source" to (r.metadata.dataOrigin.packageName ?: "health_connect"),
                        "createdAt" to FieldValue.serverTimestamp()
                    )
                    db.collection("users").document(uid).collection("spo2").document(id).set(map)
                }
            } catch (_: Exception) {}

            // Sleep sessions
            try {
                val sleep = client.readRecords(ReadRecordsRequest(SleepSessionRecord::class, timeRangeFilter = TimeRangeFilter.between(start, now))).records
                Log.i(TAG, "doWork(): sleep sessions=${sleep.size}")
                for (r in sleep) {
                    val startTs = r.startTime.toEpochMilli()
                    val endTs = r.endTime.toEpochMilli()
                    val baseId = r.metadata.id ?: "sleep"
                    val id = "${baseId}_${startTs}_${endTs}"
                    val map = hashMapOf(
                        "start" to startTs,
                        "end" to endTs,
                        "title" to (r.title ?: ""),
                        "source" to (r.metadata.dataOrigin.packageName ?: "health_connect"),
                        "createdAt" to FieldValue.serverTimestamp()
                    )
                    db.collection("users").document(uid).collection("sleep_sessions").document(id).set(map)
                }
            } catch (_: Exception) {}

            Log.i(TAG, "doWork(): success")
            return Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "doWork(): error", e)
            return Result.retry()
        }
    }
}
