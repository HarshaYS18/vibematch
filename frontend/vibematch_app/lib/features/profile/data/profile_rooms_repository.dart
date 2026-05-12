import '../../rooms/data/live_room_membership_service.dart';

class ProfileRoomRecord {
  const ProfileRoomRecord({
    required this.roomId,
    required this.roomName,
    required this.language,
    required this.modeTitle,
    required this.onlineCount,
    required this.role,
    this.isLive = true,
  });

  final String roomId;
  final String roomName;
  final String language;
  final String modeTitle;
  final int onlineCount;
  final ProfileRoomRole role;
  final bool isLive;

  String get roleLabel {
    switch (role) {
      case ProfileRoomRole.owner:
        return 'Owner';
      case ProfileRoomRole.admin:
        return 'Admin';
      case ProfileRoomRole.member:
        return 'Member';
    }
  }
}

enum ProfileRoomRole { owner, admin, member }

class ProfileRoomsRepository {
  const ProfileRoomsRepository();

  List<ProfileRoomRecord> loadMyRooms({
    required int userId,
    int? publicUserId,
  }) {
    final records = <ProfileRoomRecord>[
      ..._mockOwnerAdminMemberRooms,
      ..._acceptedMemberRoomsFor(userId: userId, publicUserId: publicUserId),
    ];

    final deduped = <String, ProfileRoomRecord>{};
    for (final record in records) {
      deduped.putIfAbsent(record.roomId, () => record);
    }

    return deduped.values.toList(growable: false);
  }

  int publicRoomsCountFor({
    required int publicUserId,
  }) {
    return loadMyRooms(
      userId: publicUserId,
      publicUserId: publicUserId,
    ).length;
  }

  List<ProfileRoomRecord> _acceptedMemberRoomsFor({
    required int userId,
    int? publicUserId,
  }) {
    final ids = <String>{
      userId.toString(),
      'user_$userId',
      if (publicUserId != null) publicUserId.toString(),
      if (publicUserId != null) 'user_$publicUserId',
    };

    return LiveRoomMembershipService.memberRoomsForUserIds(ids).map((snapshot) {
      return ProfileRoomRecord(
        roomId: snapshot.roomId,
        roomName: snapshot.roomName?.trim().isNotEmpty == true ? snapshot.roomName!.trim() : 'Member Room',
        language: snapshot.language?.trim().isNotEmpty == true ? snapshot.language!.trim() : 'Telugu',
        modeTitle: snapshot.modeTitle?.trim().isNotEmpty == true ? snapshot.modeTitle!.trim() : 'Open',
        onlineCount: snapshot.onlineCount ?? 1,
        role: ProfileRoomRole.member,
      );
    }).toList(growable: false);
  }

  List<ProfileRoomRecord> get _mockOwnerAdminMemberRooms {
    return const [
      ProfileRoomRecord(
        roomId: 'VM257808',
        roomName: 'Founder Lounge',
        language: 'Telugu',
        modeTitle: 'Open',
        onlineCount: 128,
        role: ProfileRoomRole.owner,
      ),
      ProfileRoomRecord(
        roomId: 'VM482190',
        roomName: 'Moon Fam Live',
        language: 'Hindi',
        modeTitle: 'Members Only',
        onlineCount: 76,
        role: ProfileRoomRole.admin,
      ),
      ProfileRoomRecord(
        roomId: 'VM739145',
        roomName: 'Late Night Music',
        language: 'English',
        modeTitle: 'Open',
        onlineCount: 214,
        role: ProfileRoomRole.member,
      ),
    ];
  }
}
