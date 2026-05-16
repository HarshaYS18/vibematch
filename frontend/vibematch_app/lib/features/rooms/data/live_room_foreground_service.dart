import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LiveRoomForegroundService {
  const LiveRoomForegroundService._();

  static const MethodChannel _channel = MethodChannel('vibematch/live_room_service');

  static Future<bool> start({required String roomName, required String roomId}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final started = await _channel.invokeMethod<bool>('startLiveRoomService', <String, Object?>{
        'roomName': roomName,
        'roomId': roomId,
      });
      return started == true;
    } catch (error) {
      debugPrint('[VibeMatchLiveRoomService] start failed: $error');
      return false;
    }
  }

  static Future<void> stop() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<bool>('stopLiveRoomService');
    } catch (error) {
      debugPrint('[VibeMatchLiveRoomService] stop failed: $error');
    }
  }
}
