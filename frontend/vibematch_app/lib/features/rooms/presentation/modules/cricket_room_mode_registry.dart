import '../widgets/room_theme.dart';
import 'cricket_mode_module.dart';
import 'cricket_room_mode_module.dart';
import 'cricket_room_mode_signal.dart';

class CricketRoomModeRegistry {
  CricketRoomModeRegistry._();

  static final Map<String, CricketRoomModeController> _controllers =
      <String, CricketRoomModeController>{};

  static CricketRoomModeController controllerFor({
    required String roomId,
    required String roomName,
  }) {
    final safeRoomId = roomId.trim().isEmpty ? 'VM257808' : roomId.trim();
    return _controllers.putIfAbsent(
      safeRoomId,
      () => CricketRoomModeController(roomId: safeRoomId, roomName: roomName),
    );
  }

  static CricketRoomModeController syncRoomModeFromSignal({
    required String roomId,
    required String roomName,
    required String currentLayoutId,
  }) {
    final controller = controllerFor(roomId: roomId, roomName: roomName);
    final shouldBeActive = CricketRoomModeSignal.isActive(roomId);
    final setup = CricketRoomModeSignal.setupFor(roomId);

    if (shouldBeActive && !controller.active) {
      controller.startRoomMode(
        currentLayoutId: currentLayoutId,
        currentBackground: cricketFloodlightArenaBackgroundTheme,
        setup: setup,
      );
    }

    if (!shouldBeActive && controller.active) {
      controller.endRoomMode();
    }

    return controller;
  }

  static void activateRoom({required String roomId}) {
    CricketRoomModeSignal.activate(roomId);
  }

  static void deactivateRoom({required String roomId}) {
    CricketRoomModeSignal.deactivate(roomId);
  }

  static bool isCricketBackground(RoomBackgroundTheme theme) {
    return cricketModeBackgroundThemes.any((item) => item.id == theme.id);
  }

  static bool isCricketThemeId(String themeId) {
    return cricketModeBackgroundThemes.any((item) => item.id == themeId);
  }

  static void disposeRoom(String roomId) {
    final safeRoomId = roomId.trim().isEmpty ? roomId : roomId.trim();
    _controllers.remove(safeRoomId)?.dispose();
    CricketRoomModeSignal.deactivate(safeRoomId);
  }
}
