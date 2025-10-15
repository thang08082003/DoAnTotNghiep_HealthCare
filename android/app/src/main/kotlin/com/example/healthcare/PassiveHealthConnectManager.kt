package com.example.healthcare

import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.changes.Change
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.OxygenSaturationRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
// TODO: Passive Monitoring (Health Services / Health Connect) temporarily disabled due to
// dependency API mismatch. We keep periodic WorkManager fallback below.
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Constraints
import androidx.work.NetworkType
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.runBlocking

/**
 * Manager to register/unregister Health Connect passive listener using a BroadcastReceiver.
 * It also provides helpers to enqueue a worker to drain changes.
 */
object PassiveHealthConnectManager {
    private const val TAG = "HC_PASSIVE"
    private const val RECEIVER_ACTION = "com.example.healthcare.HEALTH_PASSIVE_CHANGES"
    const val UNIQUE_WORK_DRAIN_PERIODIC = "health-passive-drain-periodic"
    const val UNIQUE_WORK_DRAIN_ONESHOT = "health-passive-drain-once"

    fun enable(context: Context) {
        Log.i(TAG, "enable(): start")
        // Ensure app has permissions; if not, throw to inform Dart side
        val client = HealthConnectClient.getOrCreate(context)
        val perms = setOf(
            HealthPermission.getReadPermission(HeartRateRecord::class),
            HealthPermission.getReadPermission(OxygenSaturationRecord::class),
            HealthPermission.getReadPermission(SleepSessionRecord::class)
        )
        val granted = runBlocking { client.permissionController.getGrantedPermissions() }
        val hasAll = perms.all { it in granted }
        Log.i(TAG, "enable(): permissions granted=${granted.size}, hasAll=$hasAll")
        if (!hasAll) {
            Log.w(TAG, "enable(): missing Health Connect permissions, abort")
            throw IllegalStateException("Health Connect permissions chưa được cấp đủ")
        }

        // Passive Monitoring registration is temporarily disabled. We'll rely on periodic drain as fallback.

        // Approximate passive by scheduling a periodic sync every 15 minutes
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .setRequiresBatteryNotLow(true)
            .build()
        val periodic = PeriodicWorkRequestBuilder<PassiveDrainWorker>(15, TimeUnit.MINUTES)
            .setConstraints(constraints)
            .build()
        val wm = WorkManager.getInstance(context)
        Log.i(TAG, "enable(): enqueueUniquePeriodicWork name=$UNIQUE_WORK_DRAIN_PERIODIC")
        wm.enqueueUniquePeriodicWork(
            UNIQUE_WORK_DRAIN_PERIODIC,
            ExistingPeriodicWorkPolicy.UPDATE,
            periodic
        )
        // Also kick off an immediate drain once
        enqueueDrain(context)
        Log.i(TAG, "enable(): done")
    }

    fun disable(context: Context) {
        Log.i(TAG, "disable(): cancelUniqueWork name=$UNIQUE_WORK_DRAIN_PERIODIC")
        // Cancel background periodic drains
        WorkManager.getInstance(context).cancelUniqueWork(UNIQUE_WORK_DRAIN_PERIODIC)

        // Passive Monitoring unregistration is temporarily disabled.
        Log.i(TAG, "disable(): done")
    }

    fun enqueueDrain(context: Context) {
        Log.i(TAG, "enqueueDrain(): enqueue one-time worker for $UNIQUE_WORK_DRAIN_ONESHOT")
        val req = OneTimeWorkRequestBuilder<PassiveDrainWorker>().build()
        WorkManager.getInstance(context)
            .enqueueUniqueWork(UNIQUE_WORK_DRAIN_ONESHOT, ExistingWorkPolicy.APPEND_OR_REPLACE, req)
    }
}
