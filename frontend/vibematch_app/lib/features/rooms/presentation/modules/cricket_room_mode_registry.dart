import '../widgets/room_theme.dart';
import 'cricket_mode_module.dart';
import 'cricket_room_mode_module.dart';

class CricketRoomModeRegistry {
  CricketRoomModeRegistry._();

  static final Map<String, CricketRoomModeController> _controllers =
      <String, CricketRoomModeController>{};

  static CricketRoomModeController controllerFor({
    required String roomId,
    required String roomName,
  }) {
    return _controllers.putIfAbsent(
      roomId,
      () => CricketRoomModeController(roomId: roomId, roomName: roomName),
    );
  }

  static bool isCricketBackground(RoomBackgroundTheme theme) {
    return cricketModeBackgroundThemes.any((item) => item.id == theme.id);
  }

  static bool isCricketThemeId(String themeId) {
    return cricketModeBackgroundThemes.any((item) => item.id == themeId);
  }

  static void disposeRoom(String roomId) {
    _controllers.remove(roomId)?.dispose();
  }
}
