import '../live_room_models.dart';
import '../widgets/room_theme.dart';

class LiveRoomSettingsController {
  const LiveRoomSettingsController();

  String roomImagesSystemMessage(bool enabled) {
    return enabled ? 'Images enabled' : 'Images disabled';
  }

  String guestMessagesSystemMessage(bool enabled) {
    return enabled ? 'Guest messages enabled' : 'Guest messages disabled';
  }

  String applyOnlyModeSystemMessage(bool enabled) {
    return enabled ? 'Apply mode enabled' : 'Free mode enabled';
  }

  String privacyModeSystemMessage(RoomPrivacyMode mode) {
    return 'Room mode changed to ${mode.label}';
  }

  String backgroundAppliedToast(RoomBackgroundTheme theme) {
    return '${theme.name} applied';
  }

  bool canShowJoinRequests({
    required bool canManageRoom,
    required int joinRequestCount,
  }) {
    return canManageRoom && joinRequestCount > 0;
  }
}
