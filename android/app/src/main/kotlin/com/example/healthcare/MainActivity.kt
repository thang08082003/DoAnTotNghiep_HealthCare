package com.example.healthcare

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraManager
import android.content.Context
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterFragmentActivity() {
	private val FOREGROUND_CHANNEL = "com.example.healthcare/foreground"
	private val PASSIVE_CHANNEL = "com.example.healthcare/passive"
	private var methodChannel: MethodChannel? = null
	private var passiveChannel: MethodChannel? = null

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		// Turn screen on and show over lock screen for incoming calls
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
			setShowWhenLocked(true)
			setTurnScreenOn(true)
		} else {
			window.addFlags(
				WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
				WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
			)
		}
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
