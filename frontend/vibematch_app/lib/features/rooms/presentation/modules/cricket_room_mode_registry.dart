import '../widgets/room_theme.dart';
import 'cricket_mode_module.dart';

/// Stateless Cricket Mode theme helpers.
///
/// Runtime controller ownership is room-scoped in LiveRoomControllerBundle.
/// This compatibility name remains temporarily for pure theme predicates only.
class CricketRoomModeRegistry {
  const CricketRoomModeRegistry._();

  static bool isCricketBackground(RoomBackgroundTheme theme) {
    return cricketModeBackgroundThemes.any((item) => item.id == theme.id);
  }

  static bool isCricketThemeId(String themeId) {
    return cricketModeBackgroundThemes.any((item) => item.id == themeId);
  }
}
