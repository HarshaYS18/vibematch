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
    final adjustedBackendCount = backendOnlineCount - _locallyKickedOutUserIds.length;
    return adjustedBackendCount > visibleRoomUsersCount ? adjustedBackendCount : visibleRoomUsersCount;
  }

  bool canKickOutUser({
    required SeatUser target,
    required bool canManageRoom,
  }) {
    if (!canManageRoom) return false;
    if (target.id == currentUser.id) return false;
    if (_isFounderOwner(target)) return false;

    if (_isOwnerLevel(target)) {
      return _isFounderOwner(currentUser) || _isOwnerLevel(currentUser) || _isMonitorTeam(currentUser);
    }

    if (_isMonitorTeam(target)) {
      return _isFounderOwner(currentUser) || _isOwnerLevel(currentUser) || _isMonitorTeam(currentUser);
    }

    if (target.isRoomAdmin || target.isHost) {
      return _isFounderOwner(currentUser) || _isOwnerLevel(currentUser) || _isMonitorTeam(currentUser);
    }

    return currentUser.isHost || currentUser.isRoomAdmin || _isMonitorTeam(currentUser);
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

  bool _isFounderOwner(SeatUser user) {
    final id = user.id.toLowerCase();
    final role = user.roleLabel.toLowerCase();
    return id == 'founder_owner' || role.contains('founder owner') || role.contains('super owner');
  }

  bool _isOwnerLevel(SeatUser user) {
    final role = user.roleLabel.toLowerCase();
    return user.isHost || role.contains('owner') || role.contains('channel host');
  }

  bool _isMonitorTeam(SeatUser user) {
    final role = user.roleLabel.toLowerCase();
    return role.contains('monitor') || role.contains('moderator');
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
