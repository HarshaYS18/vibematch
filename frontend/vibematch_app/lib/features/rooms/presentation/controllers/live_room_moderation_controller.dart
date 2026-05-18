import '../../data/room_moderation_repository.dart';
import '../live_room_models.dart';

class LiveRoomModerationController {
  LiveRoomModerationController({required this.currentUser});

  final SeatUser currentUser;

  bool isLocallyKickedOut(String userId) {
    return false;
  }

  int safeOnlineCount({
    required int backendOnlineCount,
    required int visibleRoomUsersCount,
  }) {
    if (backendOnlineCount >= 0) return backendOnlineCount;
    return visibleRoomUsersCount < 0 ? 0 : visibleRoomUsersCount;
  }

  bool canKickOutUser({required SeatUser target, required bool canManageRoom}) {
    if (target.id == currentUser.id) return false;

    final viewerRole = _platformRoomRole(currentUser);
    final targetRole = _platformRoomRole(target);

    // Founder Owner / Super Owner and Owner must get moderation action access
    // even when they are not room admins. Backend still validates every kick.
    final viewerIsTopOfficial =
        viewerRole == _RoomPlatformRole.superOwner ||
        viewerRole == _RoomPlatformRole.owner;

    if (!canManageRoom && !viewerIsTopOfficial) return false;

    // Super Owner and Owner cannot kick each other from any room.
    if (viewerRole == _RoomPlatformRole.superOwner &&
        targetRole == _RoomPlatformRole.owner) {
      return false;
    }
    if (viewerRole == _RoomPlatformRole.owner &&
        targetRole == _RoomPlatformRole.superOwner) {
      return false;
    }
    if (viewerRole == _RoomPlatformRole.owner &&
        targetRole == _RoomPlatformRole.owner) {
      return false;
    }

    // Super Owner and Owner can kick normal officials/admins/room admins/users.
    if (viewerIsTopOfficial) {
      return targetRole != _RoomPlatformRole.superOwner &&
          targetRole != _RoomPlatformRole.owner;
    }

    // Room admins can only kick normal users, never platform officials/admins.
    return targetRole == _RoomPlatformRole.normal;
  }

  Future<LiveRoomModerationResult> kickOutUser({
    required String roomId,
    required SeatUser target,
    required RoomKickoutDuration duration,
    required bool canManageRoom,
  }) async {
    if (!canKickOutUser(target: target, canManageRoom: canManageRoom)) {
      return LiveRoomModerationResult(
        systemMessage:
            '${currentUser.name} cannot remove ${target.name} because this account is protected.',
      );
    }

    return LiveRoomModerationResult(
      removedUserId: target.id,
      systemMessage:
          '${currentUser.name} requested removal of ${target.name} for ${duration.label}',
    );
  }

  _RoomPlatformRole _platformRoomRole(SeatUser user) {
    final id = user.id.toLowerCase();
    final role = user.roleLabel.toLowerCase();

    if (id == 'user_6922022' ||
        id == 'founder_owner' ||
        role.contains('founder owner') ||
        role.contains('super owner')) {
      return _RoomPlatformRole.superOwner;
    }

    // Keep channel host separate from platform Owner. A room host should not
    // receive platform Owner kick privileges unless their actual role says Owner.
    if (role == 'owner' ||
        role.contains('official owner') ||
        role.contains('platform owner')) {
      return _RoomPlatformRole.owner;
    }

    if (role.contains('superadmin') ||
        role.contains('super admin') ||
        role == 'admin' ||
        role.contains('administrator') ||
        role.contains('monitor') ||
        role == 'cs' ||
        role.contains('customer service') ||
        role.contains('support')) {
      return _RoomPlatformRole.official;
    }

    return _RoomPlatformRole.normal;
  }

  void dispose() {}
}

enum _RoomPlatformRole { normal, official, owner, superOwner }

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
