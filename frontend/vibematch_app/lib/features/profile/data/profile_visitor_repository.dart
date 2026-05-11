import '../../auth/models/current_user.dart';

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

  final List<ProfileVisitorRecord> _records = <ProfileVisitorRecord>[];

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
}
