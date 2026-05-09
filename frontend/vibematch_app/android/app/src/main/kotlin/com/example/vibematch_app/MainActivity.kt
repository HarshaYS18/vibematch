package com.example.vibematch_app

import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIVE_ROOM_SERVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLiveRoomService" -> {
                    val roomName = call.argument<String>("roomName") ?: "Live Room"
                    val roomId = call.argument<String>("roomId") ?: "Vibe Match"
                    startLiveRoomService(roomName, roomId)
                    result.success(true)
                }
                "stopLiveRoomService" -> {
                    stopLiveRoomService()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startLiveRoomService(roomName: String, roomId: String) {
        val intent = Intent(this, LiveRoomForegroundService::class.java).apply {
            putExtra(LiveRoomForegroundService.EXTRA_ROOM_NAME, roomName)
            putExtra(LiveRoomForegroundService.EXTRA_ROOM_ID, roomId)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(this, intent)
        } else {
            startService(intent)
        }
    }

    private fun stopLiveRoomService() {
        stopService(Intent(this, LiveRoomForegroundService::class.java))
    }

    companion object {
        private const val LIVE_ROOM_SERVICE_CHANNEL = "vibematch/live_room_service"
    }
}
