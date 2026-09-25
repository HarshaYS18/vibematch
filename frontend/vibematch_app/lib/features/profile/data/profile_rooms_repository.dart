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
