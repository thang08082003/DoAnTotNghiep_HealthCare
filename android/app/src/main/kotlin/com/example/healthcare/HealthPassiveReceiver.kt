package com.example.healthcare

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receives passive change broadcasts and schedules a worker to drain changes from Health Connect.
 */
class HealthPassiveReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Schedule drain worker
        PassiveHealthConnectManager.enqueueDrain(context)
    }
}
