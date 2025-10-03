package com.example.healthcare

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "com.example.healthcare/foreground"
	private var methodChannel: MethodChannel? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
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

		// Handle possible payload if app/activity launched from notification
		val payload = intent?.getStringExtra("payload")
		if (!payload.isNullOrEmpty()) {
			// Delay slightly to ensure Flutter side is ready
			flutterEngine.dartExecutor.binaryMessenger.let {
				methodChannel?.invokeMethod("onNotificationTap", mapOf("payload" to payload))
			}
			intent?.removeExtra("payload")
		}
	}
}
