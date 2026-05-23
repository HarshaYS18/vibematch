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

  static CricketRoomModeController? syncRoomModeFromSignal({
    required String roomId,
    required String roomName,
    required String currentLayoutId,
  }) {
    final shouldBeActive = CricketRoomModeSignal.isActive(roomId);
    if (!shouldBeActive) {
      _disposeControllerOnly(roomId);
      return null;
    }

    final controller = controllerFor(roomId: roomId, roomName: roomName);
    final setup = CricketRoomModeSignal.setupFor(roomId);

    if (!controller.active) {
      controller.startRoomMode(
        currentLayoutId: currentLayoutId,
        currentBackground: cricketFloodlightArenaBackgroundTheme,
        setup: setup,
      );
    }

    return controller;
  }

  static void activateRoom({required String roomId}) {
    CricketRoomModeSignal.activate(roomId);
  }

  static void deactivateRoom({required String roomId}) {
    _disposeControllerOnly(roomId);
    CricketRoomModeSignal.deactivate(roomId);
  }

  static bool isCricketBackground(RoomBackgroundTheme theme) {
    return cricketModeBackgroundThemes.any((item) => item.id == theme.id);
  }

  static bool isCricketThemeId(String themeId) {
    return cricketModeBackgroundThemes.any((item) => item.id == themeId);
  }

  static void disposeRoom(String roomId) {
    final safeRoomId = _safeRoomId(roomId);
    _controllers.remove(safeRoomId)?.dispose();
    CricketRoomModeSignal.deactivate(safeRoomId);
  }

  static void _disposeControllerOnly(String roomId) {
    _controllers.remove(_safeRoomId(roomId))?.dispose();
  }

  static String _safeRoomId(String roomId) {
    return roomId.trim().isEmpty ? roomId : roomId.trim();
  }
}
