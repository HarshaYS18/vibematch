import '../../../../app/app_routes.dart';
import '../../../auth/models/current_user.dart';

class LiveRoomRouteViewArgs {
  const LiveRoomRouteViewArgs({
    required this.roomName,
    required this.roomId,
    required this.language,
    required this.modeTitle,
    required this.onlineCount,
    this.currentUser,
    this.lockPassword,
    this.entryTransition = LiveRoomEntryTransition.standard,
  });

  final String roomName;
  final String roomId;
  final String language;
  final String modeTitle;
  final int onlineCount;
  final CurrentUser? currentUser;
  final String? lockPassword;
  final LiveRoomEntryTransition entryTransition;
}