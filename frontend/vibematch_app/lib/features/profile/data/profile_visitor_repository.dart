import '../../auth/models/current_user.dart';
import '../../auth/models/role_badge.dart';

class ProfileVisitorRecord {
  const ProfileVisitorRecord({
    required this.id,
    required this.profileOwnerUserId,
    required this.visitorUser,
    required this.visitedAt,
    this.source = 'public_profile',
  });

  final String id;
  final int profileOwnerUserId;
  final CurrentUser visitorUser;
  final DateTime visitedAt;
  final String source;

  String get displayName => visitorUser.displayName ?? visitorUser.username ?? 'Vibe User';
  String get visibleId => visitorUser.visibleId;
  String get roleLabel => visitorUser.roleDisplayLabel;
}

class ProfileVisitorRepository {
  ProfileVisitorRepository._();

  static final ProfileVisitorRepository instance = ProfileVisitorRepository._();

  final List<ProfileVisitorRecord> _records = <ProfileVisitorRecord>[
    ProfileVisitorRecord(
      id: 'visitor_riya_01',
      profileOwnerUserId: 1,
      visitorUser: CurrentUser.mockNormalUser(),
      visitedAt: DateTime.now().subtract(const Duration(minutes: 18)),
      source: 'public_profile',
    ),
    ProfileVisitorRecord(
      id: 'visitor_meera_01',
      profileOwnerUserId: 1,
      visitorUser: _mockVisitor(
        id: 3,
        publicUserId: 6418006621,
        username: 'meera_music',
        displayName: 'Meera',
      ),
      visitedAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 35)),
      source: 'public_profile',
    ),
    ProfileVisitorRecord(
      id: 'visitor_arjun_01',
      profileOwnerUserId: 1,
      visitorUser: _mockVisitor(
        id: 4,
        publicUserId: 6418002480,
        username: 'arjun_live',
        displayName: 'Arjun',
      ),
      visitedAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      source: 'public_profile',
    ),
  ];

  void recordVisit({
    required CurrentUser profileOwner,
    required CurrentUser visitor,
    String source = 'public_profile',
  }) {
    if (profileOwner.id == visitor.id) return;

    final existingIndex = _records.indexWhere(
      (record) => record.profileOwnerUserId == profileOwner.id && record.visitorUser.id == visitor.id,
    );

    final record = ProfileVisitorRecord(
      id: 'visitor_${profileOwner.id}_${visitor.id}',
      profileOwnerUserId: profileOwner.id,
      visitorUser: visitor,
      visitedAt: DateTime.now(),
      source: source,
    );

    if (existingIndex >= 0) {
      _records[existingIndex] = record;
    } else {
      _records.add(record);
    }
  }

  List<ProfileVisitorRecord> visitorsForUser(int profileOwnerUserId) {
    final results = _records.where((record) => record.profileOwnerUserId == profileOwnerUserId).toList()
      ..sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    return List.unmodifiable(results);
  }

  static CurrentUser _mockVisitor({
    required int id,
    required int publicUserId,
    required String username,
    required String displayName,
  }) {
    final now = DateTime.now();
    final roleBadge = RoleBadge.fromRole('user');
    return CurrentUser(
      id: id,
      publicUserId: publicUserId,
      displayCustomId: null,
      username: username,
      displayName: displayName,
      avatarUrl: null,
      bio: null,
      roles: const ['user'],
      primaryRole: 'user',
      primaryRoleBadge: roleBadge,
      roleBadges: [roleBadge],
      isActive: true,
      isBanned: false,
      lastDeviceId: 'mock-device-$id',
      lastLoginAt: now.subtract(const Duration(hours: 1)),
      lastSeenAt: now.subtract(const Duration(minutes: 12)),
      createdAt: now.subtract(const Duration(days: 120)),
      updatedAt: now,
    );
  }
}
