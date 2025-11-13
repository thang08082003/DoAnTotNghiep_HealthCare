package com.example.healthcare

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraManager
import android.content.Context
import android.view.WindowManager
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterFragmentActivity(), DefaultLifecycleObserver {
	private val FOREGROUND_CHANNEL = "com.example.healthcare/foreground"
	private val PASSIVE_CHANNEL = "com.example.healthcare/passive"
	private var methodChannel: MethodChannel? = null
	private var passiveChannel: MethodChannel? = null

	companion object {
		@Volatile
		var isAppInForeground = false
	}

	override fun onCreate(savedInstanceState: Bundle?) {
		super<FlutterFragmentActivity>.onCreate(savedInstanceState)
		// Register lifecycle observer
		ProcessLifecycleOwner.get().lifecycle.addObserver(this)
		
		// Turn screen on and show over lock screen for incoming calls
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
			setShowWhenLocked(true)
			setTurnScreenOn(true)
		} else {
			@Suppress("DEPRECATION")
			window.addFlags(
				WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
				WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
			)
		}
	}

	override fun onStart(owner: LifecycleOwner) {
		super<DefaultLifecycleObserver>.onStart(owner)
		isAppInForeground = true
	}

	override fun onStop(owner: LifecycleOwner) {
		super<DefaultLifecycleObserver>.onStop(owner)
		isAppInForeground = false
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		GeneratedPluginRegistrant.registerWith(flutterEngine)
		methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_CHANNEL)
		methodChannel?.setMethodCallHandler { call, result ->
				when (call.method) {
					"startForegroundService" -> {
						val userId = call.argument<String>("userId")
						if (userId.isNullOrEmpty()) {
							result.error("ARG", "userId is required", null)
							return@setMethodCallHandler
						}
						val intent = Intent(this, ForegroundNotificationService::class.java)
						intent.putExtra("userId", userId)
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
							startForegroundService(intent)
						} else {
							startService(intent)
						}
						result.success(true)
					}
					"stopForegroundService" -> {
						val intent = Intent(this, ForegroundNotificationService::class.java)
						stopService(intent)
						result.success(true)
					}
					"cancelIncomingCallNotification" -> {
						val callId = call.argument<String>("callId")
						if (callId.isNullOrEmpty()) {
							result.error("ARG", "callId is required", null)
							return@setMethodCallHandler
						}
						// Cancel notification using the same ID calculation as ForegroundNotificationService
						val notifId = (callId.hashCode() and 0x7fffffff) % 100000000
						val nm = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
						nm.cancel(notifId)
						result.success(true)
					}
					else -> result.notImplemented()
				}
			}

		val payload = intent?.getStringExtra("payload")
		if (!payload.isNullOrEmpty()) {
			flutterEngine.dartExecutor.binaryMessenger.let {
				methodChannel?.invokeMethod("onNotificationTap", mapOf("payload" to payload))
			}
			intent?.removeExtra("payload")
		}
		passiveChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PASSIVE_CHANNEL)
		passiveChannel?.setMethodCallHandler { call, result ->
			when (call.method) {
				"enablePassiveListener" -> {
					try {
						val role = call.argument<String>("role") ?: ""
						if (role.equals("doctor", ignoreCase = true)) {
							result.error("PASSIVE", "Passive sync is not allowed for doctor role", null)
							return@setMethodCallHandler
						}
						PassiveHealthConnectManager.enable(this)
						result.success(true)
					} catch (e: Exception) {
						result.error("PASSIVE", e.message, null)
					}
				}
				"disablePassiveListener" -> {
					try {
						PassiveHealthConnectManager.disable(this)
						result.success(true)
					} catch (e: Exception) {
						result.error("PASSIVE", e.message, null)
					}
				}
				else -> result.notImplemented()
			}
		}

	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		val payload = intent.getStringExtra("payload")
		if (!payload.isNullOrEmpty()) {
			methodChannel?.invokeMethod("onNotificationTap", mapOf("payload" to payload))
			intent.removeExtra("payload")
		}
	}

    private fun setTorch(on: Boolean) {
        try {
            val cm: CameraManager? = getSystemService(Context.CAMERA_SERVICE) as CameraManager?
            val cameraId = cm?.cameraIdList?.firstOrNull()
            if (cameraId != null) cm.setTorchMode(cameraId, on)
        } catch (_: CameraAccessException) {
        } catch (_: SecurityException) {
        }
    }
}
