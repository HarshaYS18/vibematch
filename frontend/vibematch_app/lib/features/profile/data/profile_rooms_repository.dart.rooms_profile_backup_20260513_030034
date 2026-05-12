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

  // Future backend mapping:
  // GET /rooms/me
  // Returns all rooms where the authenticated user is owner, admin, or member.
  //
  // Important privacy rule:
  // - Me page can show the authenticated user's room memberships.
  // - Public profile page must not expose another user's full room list.
  // - Public profile can show safe public counters/status only, subject to room
  //   privacy rules. Secret Vibe rooms must never be exposed publicly.

  List<ProfileRoomRecord> loadMyRooms({required int userId}) {
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
