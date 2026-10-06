package com.funkey.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var screenshotBlocked = false
    private var growthChannel: MethodChannel? = null
    private var pendingGrowthLink: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingGrowthLink = intent?.dataString
        super.onCreate(savedInstanceState)
        applyScreenshotPolicy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val link = intent.dataString ?: return
        val channel = growthChannel
        if (channel == null) {
            pendingGrowthLink = link
        } else {
            channel.invokeMethod("link", link)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        growthChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GROWTH_CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialLink" -> {
                        val link = pendingGrowthLink
                        pendingGrowthLink = null
                        result.success(link)
                    }
                    "shareText" -> {
                        val text = call.argument<String>("text")?.trim().orEmpty()
                        if (text.isEmpty()) {
                            result.error("invalid_share", "Share text is empty.", null)
                        } else {
                            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, text)
                            }
                            startActivity(Intent.createChooser(sendIntent, null))
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIVE_ROOM_SERVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLiveRoomService" -> {
                    val roomName = call.argument<String>("roomName") ?: "Live Room"
                    val roomId = call.argument<String>("roomId") ?: "FunKey"
                    val started = startLiveRoomServiceSafely(roomName, roomId)
                    result.success(started)
                }
                "stopLiveRoomService" -> {
                    stopLiveRoomService()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, POWER_STATE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPowerState" -> {
                    val batteryManager = getSystemService(BATTERY_SERVICE) as BatteryManager
                    val rawLevel = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                    val level = rawLevel.takeIf { it in 0..100 }
                    val powerManager = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(
                        mapOf(
                            "batteryLevel" to level,
                            "lowPowerMode" to powerManager.isPowerSaveMode,
                        )
                    )
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREENSHOT_GUARD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setScreenshotBlocked" -> {
                    screenshotBlocked = call.argument<Boolean>("blocked") == true
                    applyScreenshotPolicy()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun applyScreenshotPolicy() {
        if (screenshotBlocked) {
            window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    private fun hasMicrophonePermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    }

    private fun askForMicrophonePermission() {
        if (hasMicrophonePermission()) return
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), 6922)
    }

    private fun startLiveRoomServiceSafely(roomName: String, roomId: String): Boolean {
        if (!hasMicrophonePermission()) {
            askForMicrophonePermission()
            return false
        }

        val intent = Intent(this, LiveRoomForegroundService::class.java).apply {
            putExtra(LiveRoomForegroundService.EXTRA_ROOM_NAME, roomName)
            putExtra(LiveRoomForegroundService.EXTRA_ROOM_ID, roomId)
        }
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(this, intent)
            } else {
                startService(intent)
            }
            true
        } catch (error: Throwable) {
            false
        }
    }

    private fun stopLiveRoomService() {
        stopService(Intent(this, LiveRoomForegroundService::class.java))
    }

    companion object {
        private const val LIVE_ROOM_SERVICE_CHANNEL = "vibematch/live_room_service"
        private const val SCREENSHOT_GUARD_CHANNEL = "vibematch/screenshot_guard"
        private const val POWER_STATE_CHANNEL = "funkey/power_state"
        private const val GROWTH_CHANNEL = "funkey/growth"
    }
}
