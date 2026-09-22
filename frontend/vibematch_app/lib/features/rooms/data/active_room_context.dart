import 'live_room_media_signaling_service.dart';

class ActiveRoomContext {
  const ActiveRoomContext._();

  static String? _roomPublicId;
  static String? _roomName;

  static String? get roomPublicId {
    final explicitRoomId = _roomPublicId?.trim();
    if (explicitRoomId != null && explicitRoomId.isNotEmpty) return explicitRoomId;

    final mediaRoomId = LiveRoomMediaSignalingService.instance.roomId?.trim();
    if (mediaRoomId != null && mediaRoomId.isNotEmpty) return mediaRoomId;

    return null;
  }

  static String? get roomName {
    final explicitRoomName = _roomName?.trim();
    if (explicitRoomName != null && explicitRoomName.isNotEmpty) return explicitRoomName;
    return null;
  }

  static void setActiveRoom({required String roomPublicId, required String roomName}) {
    final cleanRoomPublicId = roomPublicId.trim();
    final cleanRoomName = roomName.trim();
    if (cleanRoomPublicId.isEmpty) return;
    _roomPublicId = cleanRoomPublicId;
    _roomName = cleanRoomName.isEmpty ? 'Live Room' : cleanRoomName;
  }

  static void clear() {
    _roomPublicId = null;
    _roomName = null;
  }

  static void clearIfMatches(String roomPublicId) {
    final currentRoomId = _roomPublicId?.trim();
    if (currentRoomId == roomPublicId.trim()) {
      _roomPublicId = null;
      _roomName = null;
    }
  }
}
