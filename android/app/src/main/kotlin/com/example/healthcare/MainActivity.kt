package com.example.healthcare

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.hardware.Camera
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraManager
import android.os.SystemClock
import android.content.Context
import androidx.core.content.getSystemService
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterFragmentActivity() {
	private val FOREGROUND_CHANNEL = "com.example.healthcare/foreground"
	private val HRV_CHANNEL = "com.example.healthcare/hrv"
	private var methodChannel: MethodChannel? = null
	private var hrvChannel: MethodChannel? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		// Ensure plugins are registered (defensive for some environments)
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

		// HRV measurement channel
		hrvChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HRV_CHANNEL)
		hrvChannel?.setMethodCallHandler { call, result ->
			when (call.method) {
				"measureHrv" -> {
					Thread {
						val durationSec = call.argument<Int>("durationSec") ?: 60
						val useFlash = call.argument<Boolean>("useFlash") ?: true
						var cam: Camera? = null
						try {
							cam = Camera.open()
							val params = cam.parameters
							// Torch
							if (useFlash) {
								val supported = params.supportedFlashModes
								if (supported != null && supported.contains(Camera.Parameters.FLASH_MODE_TORCH)) {
									params.flashMode = Camera.Parameters.FLASH_MODE_TORCH
								}
							}
							// Prefer a small preview size
							val size = params.preferredPreviewSizeForVideo ?: params.previewSize
							params.setPreviewSize(size.width, size.height)
							params.previewFormat = android.graphics.ImageFormat.NV21
							// Continuous focus if available
							val fModes = params.supportedFocusModes
							if (fModes != null && fModes.contains(Camera.Parameters.FOCUS_MODE_CONTINUOUS_VIDEO)) {
								params.focusMode = Camera.Parameters.FOCUS_MODE_CONTINUOUS_VIDEO
							}
							cam.parameters = params
							val tex = SurfaceTexture(10)
							cam.setPreviewTexture(tex)

							val signal = ArrayList<Double>()
							val timestamps = ArrayList<Double>()
							val startNs = SystemClock.elapsedRealtimeNanos()
							val expectedLen = (durationSec * 30).coerceAtLeast(300)
							val yAvg: (ByteArray) -> Double = { data ->
								val frameSize = params.previewSize.width * params.previewSize.height
								var sum = 0L
								var i = 0
								val step = 4 // sample every 4 pixels to speed up
								while (i < frameSize) {
									sum += (data[i].toInt() and 0xFF)
									i += step
								}
								sum.toDouble() / (frameSize / step)
							}
							cam.setPreviewCallback { data, _ ->
								val nowNs = SystemClock.elapsedRealtimeNanos()
								val t = (nowNs - startNs) / 1_000_000_000.0
								if (t <= durationSec + 0.25) {
									if (data != null) {
										val v = yAvg(data)
										signal.add(v)
										timestamps.add(t)
									}
								}
							}
							cam.startPreview()
							// Wait for duration
							Thread.sleep((durationSec * 1000).toLong())
							cam.stopPreview()
							cam.setPreviewCallback(null)

							// Compute HRV natively (RMSSD/SDNN/pNN50/HR/Score)
							val stats = computeHrvNative(signal, timestamps)
							result.success(stats)
						} catch (e: Exception) {
							result.error("HRV", e.message, null)
						} finally {
							try { cam?.stopPreview() } catch (_: Exception) {}
							try { cam?.setPreviewCallback(null) } catch (_: Exception) {}
							try { cam?.release() } catch (_: Exception) {}
							if (useFlash) setTorch(false)
						}
					}.start()
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

	// --- Native HRV computation: RMSSD and HR (bpm) ---
	private fun computeHrvNative(signal: List<Double>, timestamps: List<Double>): Map<String, Any> {
		if (signal.isEmpty() || timestamps.size != signal.size) return mapOf(
			"rmssd" to Double.NaN,
			"sdnn" to Double.NaN,
			"pnn50" to Double.NaN,
			"hr" to Double.NaN,
			"hrvScore" to 0,
			"hrvLevel" to "low"
		)
		// Simple band-pass via moving average subtraction
		val mean = signal.average()
		val x = signal.map { it - mean }
		// Estimate effective sampling frequency from timestamps
		val diffs = ArrayList<Double>()
		for (i in 1 until timestamps.size) {
			val d = timestamps[i] - timestamps[i - 1]
			if (d > 0) diffs.add(d)
		}
		val fsEff = if (diffs.isNotEmpty()) 1.0 / median(diffs) else 30.0
		// Moving average smoothing window ~0.5 s
		val win = kotlin.math.max(3, (0.5 * fsEff).toInt())
		val filt = movingAverage(x, win)
		// Peak detection
		val peaks = detectPeaks(filt, fsEff)
		if (peaks.size < 3) return mapOf(
			"rmssd" to Double.NaN,
			"sdnn" to Double.NaN,
			"pnn50" to Double.NaN,
			"hr" to Double.NaN,
			"hrvScore" to 0,
			"hrvLevel" to "low"
		)
		// Discard first 5s
		val cutoff = (5.0 * fsEff).toInt()
		val peaks2 = peaks.filter { it >= cutoff }
		if (peaks2.size < 3) return mapOf(
			"rmssd" to Double.NaN,
			"sdnn" to Double.NaN,
			"pnn50" to Double.NaN,
			"hr" to Double.NaN,
			"hrvScore" to 0,
			"hrvLevel" to "low"
		)
		// RR from timestamps (ms)
		val rr = ArrayList<Double>()
		for (i in 1 until peaks2.size) {
			val dt = (timestamps[peaks2[i]] - timestamps[peaks2[i - 1]]) * 1000.0
			rr.add(dt)
		}
		// Filter RR by physiological range
		val rrFilt = rr.filter { it > 250.0 && it < 2000.0 }
		if (rrFilt.size < 2) return mapOf(
			"rmssd" to Double.NaN,
			"sdnn" to Double.NaN,
			"pnn50" to Double.NaN,
			"hr" to Double.NaN,
			"hrvScore" to 0,
			"hrvLevel" to "low"
		)
		// SDNN
		val sdnn = std(rrFilt)
		// RMSSD
		var sumSq = 0.0
		var cnt = 0
		for (i in 1 until rrFilt.size) {
			val d = rrFilt[i] - rrFilt[i - 1]
			sumSq += d * d
			cnt++
		}
		val rmssd = if (cnt > 0) kotlin.math.sqrt(sumSq / cnt.toDouble()) else Double.NaN
		// pNN50
		var above50 = 0
		for (i in 1 until rrFilt.size) {
			val d = kotlin.math.abs(rrFilt[i] - rrFilt[i - 1])
			if (d > 50.0) above50++
		}
		val pnn50 = if (rrFilt.size > 1) (above50.toDouble() / (rrFilt.size - 1).toDouble()) * 100.0 else Double.NaN
		// HR from mean RR
		val mrr = rrFilt.average()
		val hr = if (mrr > 0) 60000.0 / mrr else Double.NaN
		// Score 0..100 (simple blend, consistent with Python)
		val scoreF = (0.5 * (rmssd / 100.0) + 0.3 * (sdnn / 100.0) + 0.2 * (pnn50 / 100.0)) * 100.0
		val score = if (scoreF.isNaN() || scoreF < 0) 0 else kotlin.math.min(100.0, kotlin.math.round(scoreF)).toInt()
		val level = when {
			score < 50 -> "low"
			score <= 80 -> "medium"
			else -> "high"
		}
		return mapOf(
			"rmssd" to rmssd,
			"sdnn" to sdnn,
			"pnn50" to pnn50,
			"hr" to hr,
			"hrvScore" to score,
			"hrvLevel" to level
		)
	}

	private fun movingAverage(x: List<Double>, win: Int): List<Double> {
		if (x.isEmpty() || win <= 1) return x
		val n = x.size
		val out = DoubleArray(n)
		var sum = 0.0
		var i = 0
		while (i < win && i < n) {
			sum += x[i]
			out[i] = sum / (i + 1)
			i++
		}
		var j = 0
		while (i < n) {
			sum += x[i]
			sum -= x[j]
			out[i] = sum / win
			i++; j++
		}
		return out.toList()
	}

	private fun detectPeaks(x: List<Double>, fs: Double): List<Int> {
		if (x.size < 3) return emptyList()
		val xs = normalize(x)
		val thr = percentile(xs, 75.0)
		val refractory = kotlin.math.max(1, (0.3 * fs).toInt())
		val peaks = ArrayList<Int>()
		var i = 1
		while (i < xs.size - 1) {
			if (xs[i] > thr && xs[i] > xs[i - 1] && xs[i] >= xs[i + 1]) {
				peaks.add(i)
				i += refractory
			} else i++
		}
		return peaks
	}

	private fun normalize(x: List<Double>): List<Double> {
		val min = x.minOrNull() ?: 0.0
		val max = x.maxOrNull() ?: 0.0
		val range = max - min
		if (range <= 1e-9) return List(x.size) { 0.0 }
		return x.map { (it - min) / range }
	}

	private fun std(values: List<Double>): Double {
		val n = values.size
		if (n < 2) return Double.NaN
		val mean = values.average()
		var sum = 0.0
		for (v in values) {
			val d = v - mean
			sum += d * d
		}
		return kotlin.math.sqrt(sum / (n - 1).toDouble())
	}

	private fun percentile(values: List<Double>, p: Double): Double {
		if (values.isEmpty()) return Double.NaN
		if (p <= 0) return values.minOrNull()!!
		if (p >= 100) return values.maxOrNull()!!
		val vs = values.sorted()
		val k = (vs.size - 1) * (p / 100.0)
		val f = kotlin.math.floor(k).toInt()
		val c = kotlin.math.ceil(k).toInt()
		return if (f == c) vs[k.toInt()] else vs[f] * (c - k) + vs[c] * (k - f)
	}

	private fun median(values: List<Double>): Double {
		if (values.isEmpty()) return Double.NaN
		val vs = values.sorted()
		val n = vs.size
		val mid = n / 2
		return if (n % 2 == 1) vs[mid] else (vs[mid - 1] + vs[mid]) / 2.0
	}
}
