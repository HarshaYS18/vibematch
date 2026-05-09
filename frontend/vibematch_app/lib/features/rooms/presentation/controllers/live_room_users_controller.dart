import '../live_room_models.dart';

class LiveRoomUsersController {
  const LiveRoomUsersController();

  List<SeatUser> buildAllRoomUsers({
    required List<SeatUser> seatedUsers,
    required List<SeatUser> fallbackRoomUsers,
    required List<SeatUser> inviteUsers,
    required bool Function(String userId) isUserRemoved,
  }) {
    final users = <SeatUser>[];
    final ids = <String>{};

    void addUser(SeatUser user) {
      if (isUserRemoved(user.id)) return;
      if (ids.add(user.id)) users.add(user);
    }

    for (final user in seatedUsers) {
      addUser(user);
    }
    for (final user in fallbackRoomUsers) {
      addUser(user);
    }
    for (final user in inviteUsers) {
      addUser(user);
    }

    return users;
  }

  List<SeatUser> buildRoomAdmins(List<SeatUser> users) {
    return users.where((user) => user.isHost || user.isRoomAdmin).toList();
  }

  List<SeatUser> buildAvailableAdminUsers(List<SeatUser> users) {
    return users.where((user) => !user.isHost && !user.isRoomAdmin).toList();
  }

  List<SeatUser> buildSeatInviteUsers({
    required List<SeatUser> allRoomUsers,
    required List<SeatUser> seatedUsers,
    String currentUserId = '',
  }) {
    final seatedIds = seatedUsers.map((user) => user.id).toSet();
    return allRoomUsers
        .where((user) => user.id != currentUserId && !seatedIds.contains(user.id))
        .toList();
  }

  SeatUser resolveUserFromChatEntry({
    required ChatEntry entry,
    required List<SeatUser> allRoomUsers,
  }) {
    final senderId = entry.senderId;
    if (senderId == null) {
      return SeatUser(
        id: 'unknown_sender',
        name: entry.senderName,
        roleLabel: 'Member',
        familyName: '',
        relationshipText: '',
        vipLevel: entry.vipLevel,
        sendingLevel: entry.sendingLevel,
        receivingLevel: entry.receivingLevel,
        sentExp: 0,
        receivedExp: 0,
        medals: const [],
        avatarColors: const [],
      );
    }

    return allRoomUsers.firstWhere(
      (item) => item.id == senderId,
      orElse: () => SeatUser(
        id: senderId,
        name: entry.senderName,
        roleLabel: 'Member',
        familyName: '',
        relationshipText: '',
        vipLevel: entry.vipLevel,
        sendingLevel: entry.sendingLevel,
        receivingLevel: entry.receivingLevel,
        sentExp: 0,
        receivedExp: 0,
        medals: const [],
        avatarColors: const [],
      ),
    );
  }
}
