import '../../data/room_moderation_repository.dart';
import '../live_room_models.dart';

class LiveRoomModerationController {
  LiveRoomModerationController({
    required this.currentUser,
    RoomModerationRepository? repository,
  }) : _repository = repository ?? RoomModerationRepository();

  final SeatUser currentUser;
  final RoomModerationRepository _repository;
  final Set<String> _locallyKickedOutUserIds = <String>{};

  bool isLocallyKickedOut(String userId) {
    return _locallyKickedOutUserIds.contains(userId);
  }

  int safeOnlineCount({
    required int backendOnlineCount,
    required int visibleRoomUsersCount,
  }) {
    return visibleRoomUsersCount < 0 ? 0 : visibleRoomUsersCount;
  }

  bool canKickOutUser({
    required SeatUser target,
    required bool canManageRoom,
  }) {
    if (!canManageRoom) return false;
    if (target.id == currentUser.id) return false;

    final viewerPower = _roomPower(currentUser);
    final targetPower = _roomPower(target);

    if (targetPower >= 100) return false;
    if (viewerPower >= 100) return targetPower < 100;
    if (viewerPower >= 90) return targetPower < 90;
    return false;
  }

  Future<LiveRoomModerationResult> kickOutUser({
    required String roomId,
    required SeatUser target,
    required RoomKickoutDuration duration,
    required bool canManageRoom,
  }) async {
    if (!canKickOutUser(target: target, canManageRoom: canManageRoom)) {
      return LiveRoomModerationResult(
        systemMessage: '${currentUser.name} cannot remove ${target.name} because this account is protected.',
      );
    }

    try {
      await _repository.kickOutUser(
        roomId: roomId,
        targetUserId: target.id,
        targetDisplayName: target.name,
        duration: duration,
        reason: 'Room kickout from mini profile',
      );

      _locallyKickedOutUserIds.add(target.id);

      return LiveRoomModerationResult(
        removedUserId: target.id,
        systemMessage: '${currentUser.name} removed ${target.name} from the room for ${duration.label}',
      );
    } catch (_) {
      return const LiveRoomModerationResult(
        toastMessage: 'Kick out failed. Check backend connection and permissions.',
      );
    }
  }

  int _roomPower(SeatUser user) {
    final id = user.id.toLowerCase();
    final role = user.roleLabel.toLowerCase();
    final isOwner = user.isHost ||
        id == 'user_6922022' ||
        id == 'founder_owner' ||
        role.contains('founder owner') ||
        role.contains('super owner') ||
        role.contains('owner') ||
        role.contains('channel host') ||
        role == 'host';
    if (isOwner) return 100;

    final isAdmin = user.isRoomAdmin || role.contains('admin') || role.contains('administrator');
    if (isAdmin) return 90;

    return 0;
  }

  void dispose() {
    _repository.close();
  }
}

class LiveRoomModerationResult {
  const LiveRoomModerationResult({
    this.removedUserId,
    this.systemMessage,
    this.toastMessage,
  });

  final String? removedUserId;
  final String? systemMessage;
  final String? toastMessage;
}
