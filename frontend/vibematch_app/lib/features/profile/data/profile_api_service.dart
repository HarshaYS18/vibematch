import 'dart:async';
import 'dart:convert';

import 'package:vibematch_app/foundation/networking/feature_http_compat.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';
import '../../auth/models/current_user.dart';
import '../../auth/models/role_badge.dart';
import '../models/vip_wallet_models.dart';

class ProfileApiService {
  const ProfileApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<CurrentUser> getMe({bool forceRefresh = true}) {
    return authApiService.getCurrentUser(forceRefresh: forceRefresh);
  }

  Future<CurrentUser> updateMyProfile({
    required String displayName,
    String? bio,
    String? avatarUrl,
    List<String> coverPhotoUrls = const [],
    DateTime? dateOfBirth,
    String? gender,
    String? profession,
    String? maritalStatus,
    String? friendGenderPreference,
    String? friendMaritalPreference,
    List<String> interests = const [],
  }) async {
    final safeName = displayName.trim();
    if (safeName.isEmpty) throw Exception('Name is required.');
    final response = await http.patch(
      Uri.parse(VmApiConfig.endpoint('/users/me/profile')),
      headers: _authHeaders(),
      body: jsonEncode({
        'display_name': safeName,
        'bio': bio?.trim() ?? '',
        if (avatarUrl != null) 'avatar_url': avatarUrl.trim(),
        'cover_photo_urls': coverPhotoUrls
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
        'date_of_birth': dateOfBirth == null ? null : _dateOnly(dateOfBirth),
        'gender': gender,
        'profession': profession?.trim(),
        'marital_status': maritalStatus,
        'friend_gender_preference': friendGenderPreference,
        'friend_marital_preference': friendMaritalPreference,
        'interests': interests
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
      }),
    );
    _throwIfFailed(response, 'update profile');
    final user = CurrentUser.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    await authApiService.persistCurrentUser(user);
    return user;
  }

  Future<CurrentUser> updateCoverPhotoUrls(List<String> coverPhotoUrls) async {
    final current = await getMe(forceRefresh: false);
    return updateMyProfile(
      displayName: current.displayName ?? current.username ?? 'Vibe User',
      bio: current.bio,
      avatarUrl: current.avatarUrl,
      coverPhotoUrls: coverPhotoUrls,
      dateOfBirth: current.dateOfBirth,
      gender: current.gender,
      profession: current.profession,
      maritalStatus: current.maritalStatus,
      friendGenderPreference: current.friendGenderPreference,
      friendMaritalPreference: current.friendMaritalPreference,
      interests: current.interests,
    );
  }

  Future<PublicUserProfile> getPublicProfile(int publicUserId) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/users/profile/$publicUserId')),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'load public profile');
    return PublicUserProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<ProfileVisitorDto>> listMyProfileVisitors({
    int limit = 50,
  }) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/users/me/visitors?limit=$limit')),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'load profile visitors');

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final visitors = decoded['visitors'] as List<dynamic>? ?? const [];
    return visitors
        .whereType<Map<String, dynamic>>()
        .map(ProfileVisitorDto.fromJson)
        .toList(growable: false);
  }

  Future<FamilySummaryDto> getMyFamily() async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/families/me')),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'load my family');
    return FamilySummaryDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<FamilySummaryDto> getPublicFamily(int publicUserId) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/families/public/$publicUserId')),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'load public family');
    return FamilySummaryDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<ProfileVibeDto>> listMyVibes({int limit = 30}) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/vibes/me?limit=$limit')),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'load my Vibes');
    return _parseVibesResponse(response.body);
  }

  Future<List<ProfileVibeDto>> listPublicUserVibes(
    int publicUserId, {
    int limit = 30,
  }) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/vibes/user/$publicUserId?limit=$limit')),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'load public user Vibes');
    return _parseVibesResponse(response.body);
  }

  List<ProfileVibeDto> _parseVibesResponse(String body) {
    final decoded = jsonDecode(body);
    final posts = decoded is List<dynamic>
        ? decoded
        : decoded is Map<String, dynamic>
        ? decoded['posts'] as List<dynamic>? ?? const []
        : const [];
    return posts
        .whereType<Map<String, dynamic>>()
        .map(ProfileVibeDto.fromJson)
        .toList(growable: false);
  }

  Future<UserRelationship> getRelationship(int publicUserId) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/users/me/relationship/$publicUserId')),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'load relationship');
    return UserRelationship.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<UserRelationship> followUser(int publicUserId) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/users/follow/$publicUserId')),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'follow user');
    return UserRelationship.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<UserRelationship> unfollowUser(int publicUserId) async {
    final response = await http.delete(
      Uri.parse(VmApiConfig.endpoint('/users/follow/$publicUserId')),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'unfollow user');
    return UserRelationship.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Map<String, String> _authHeaders() {
    final access = authApiService.cachedAccessToken;
    if (access == null || access.trim().isEmpty)
      throw Exception('Please login again.');
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $access',
    };
  }

  void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final body = response.body.trim();
    if (body.isNotEmpty) {
      final decoded = _tryDecodeJson(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail']?.toString().trim();
        if (detail != null && detail.isNotEmpty) throw Exception(detail);
      } else {
        throw Exception(body);
      }
    }
    throw Exception('Failed to $action (${response.statusCode})');
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class FamilyMemberSummaryDto {
  const FamilyMemberSummaryDto({
    required this.userId,
    required this.publicUserId,
    required this.displayName,
    required this.role,
    required this.contributionExp,
    required this.joinedAt,
    this.avatarUrl,
  });

  final int userId;
  final int publicUserId;
  final String displayName;
  final String role;
  final int contributionExp;
  final DateTime joinedAt;
  final String? avatarUrl;

  factory FamilyMemberSummaryDto.fromJson(Map<String, dynamic> json) {
    return FamilyMemberSummaryDto(
      userId: _int(json['user_id'], fallback: 0),
      publicUserId: _int(json['public_user_id'], fallback: 0),
      displayName: _nullableText(json['display_name']) ?? 'Vibe User',
      avatarUrl: _nullableText(json['avatar_url']),
      role: _nullableText(json['role']) ?? 'member',
      contributionExp: _int(json['contribution_exp'], fallback: 0),
      joinedAt: _date(json['joined_at']) ?? DateTime.now(),
    );
  }
}

class FamilySummaryDto {
  const FamilySummaryDto({
    required this.hasFamily,
    required this.level,
    required this.totalExp,
    required this.memberCount,
    required this.members,
    this.id,
    this.name,
    this.bio,
    this.avatarUrl,
    this.ownerPublicUserId,
    this.ownerDisplayName,
    this.myRole,
  });

  final bool hasFamily;
  final String? id;
  final String? name;
  final String? bio;
  final String? avatarUrl;
  final int level;
  final int totalExp;
  final int? ownerPublicUserId;
  final String? ownerDisplayName;
  final int memberCount;
  final String? myRole;
  final List<FamilyMemberSummaryDto> members;

  bool get shouldShow => hasFamily && (name?.trim().isNotEmpty ?? false);
  String get safeName =>
      name?.trim().isNotEmpty == true ? name!.trim() : 'Family';
  String get safeId => id?.trim().isNotEmpty == true ? id!.trim() : 'family';
  String get safeRole =>
      myRole?.trim().isNotEmpty == true ? myRole!.trim() : 'Member';

  factory FamilySummaryDto.empty() {
    return const FamilySummaryDto(
      hasFamily: false,
      level: 0,
      totalExp: 0,
      memberCount: 0,
      members: [],
    );
  }

  factory FamilySummaryDto.fromJson(Map<String, dynamic> json) {
    final membersJson = json['members'] as List<dynamic>? ?? const [];
    final hasFamily = json['has_family'] == true || json['should_show'] == true;
    final name =
        _nullableText(json['name']) ?? _nullableText(json['family_name']);
    return FamilySummaryDto(
      hasFamily: hasFamily,
      id: _nullableText(json['id']) ?? _nullableText(json['family_id']),
      name: name,
      bio: _nullableText(json['bio']),
      avatarUrl: _nullableText(json['avatar_url']),
      level: _int(json['level'], fallback: 0),
      totalExp: _int(json['total_exp'], fallback: 0),
      ownerPublicUserId: _nullableInt(json['owner_public_user_id']),
      ownerDisplayName: _nullableText(json['owner_display_name']),
      memberCount: _int(json['member_count'], fallback: 0),
      myRole: _nullableText(json['my_role']) ?? _nullableText(json['role']),
      members: membersJson
          .whereType<Map<String, dynamic>>()
          .map(FamilyMemberSummaryDto.fromJson)
          .toList(growable: false),
    );
  }
}

class ProfileVibeAuthorDto {
  const ProfileVibeAuthorDto({
    required this.id,
    required this.publicUserId,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  final int id;
  final int publicUserId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  String get visibleName => displayName?.trim().isNotEmpty == true
      ? displayName!.trim()
      : username?.trim().isNotEmpty == true
      ? username!.trim()
      : 'Vibe User';

  factory ProfileVibeAuthorDto.fromJson(Map<String, dynamic> json) {
    return ProfileVibeAuthorDto(
      id: _int(json['id'], fallback: 0),
      publicUserId: _int(json['public_user_id'], fallback: 0),
      username: _nullableText(json['username']),
      displayName: _nullableText(json['display_name']),
      avatarUrl: _nullableText(json['avatar_url']),
    );
  }
}

class ProfileVibeDto {
  const ProfileVibeDto({
    required this.id,
    required this.caption,
    required this.mediaType,
    required this.mentions,
    required this.usesMentionAll,
    required this.author,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.reportsCount,
    required this.viewsCount,
    required this.likedByMe,
    required this.createdAt,
    this.mediaUrl,
    this.tag,
  });

  final int id;
  final String caption;
  final String mediaType;
  final String? mediaUrl;
  final String? tag;
  final List<String> mentions;
  final bool usesMentionAll;
  final ProfileVibeAuthorDto author;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int reportsCount;
  final int viewsCount;
  final bool likedByMe;
  final DateTime createdAt;

  String get title {
    final safeTag = tag?.trim();
    if (safeTag != null && safeTag.isNotEmpty) return safeTag;
    if (mediaType == 'photo') return 'Photo Vibe';
    if (mediaType == 'video') return 'Video Vibe';
    return 'Text Vibe';
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  String get likesLabel => _compactCount(likesCount);
  String get commentsLabel => _compactCount(commentsCount);

  factory ProfileVibeDto.fromJson(Map<String, dynamic> json) {
    final mentionsJson = json['mentions'] as List<dynamic>? ?? const [];
    final authorJson = json['author'] is Map<String, dynamic>
        ? json['author'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return ProfileVibeDto(
      id: _int(json['id'], fallback: 0),
      caption: _nullableText(json['caption']) ?? '',
      mediaType: (_nullableText(json['media_type']) ?? 'text').toLowerCase(),
      mediaUrl: _nullableText(json['media_url']),
      tag: _nullableText(json['tag']),
      mentions: mentionsJson
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false),
      usesMentionAll: json['uses_mention_all'] == true,
      author: ProfileVibeAuthorDto.fromJson(authorJson),
      likesCount: _int(json['likes_count'], fallback: 0),
      commentsCount: _int(json['comments_count'], fallback: 0),
      sharesCount: _int(json['shares_count'], fallback: 0),
      reportsCount: _int(json['reports_count'], fallback: 0),
      viewsCount: _int(json['views_count'], fallback: 0),
      likedByMe: json['liked_by_me'] == true,
      createdAt: _date(json['created_at']) ?? DateTime.now(),
    );
  }
}

String _compactCount(int value) {
  if (value >= 1000000)
    return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
  if (value >= 1000)
    return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  return value.toString();
}

class ProfileVisitorDto {
  const ProfileVisitorDto({
    required this.id,
    required this.visitorUserId,
    required this.visitorPublicUserId,
    required this.visitorVisibleId,
    required this.visitorDisplayName,
    required this.visitorRoleLabel,
    required this.visitedAt,
    required this.visitCount,
    this.visitorUsername,
    this.visitorAvatarUrl,
  });

  final String id;
  final int visitorUserId;
  final int visitorPublicUserId;
  final String visitorVisibleId;
  final String visitorDisplayName;
  final String visitorRoleLabel;
  final DateTime visitedAt;
  final int visitCount;
  final String? visitorUsername;
  final String? visitorAvatarUrl;

  String get displayName =>
      visitorDisplayName.trim().isEmpty ? 'Vibe User' : visitorDisplayName;
  String get visibleId => visitorVisibleId.trim().isEmpty
      ? visitorPublicUserId.toString()
      : visitorVisibleId;
  String get roleLabel =>
      visitorRoleLabel.trim().isEmpty ? 'User' : visitorRoleLabel;

  factory ProfileVisitorDto.fromJson(Map<String, dynamic> json) {
    return ProfileVisitorDto(
      id: json['id']?.toString() ?? '',
      visitorUserId: _int(json['visitor_user_id'], fallback: 0),
      visitorPublicUserId: _int(json['visitor_public_user_id'], fallback: 0),
      visitorVisibleId: json['visitor_visible_id']?.toString() ?? '',
      visitorDisplayName:
          json['visitor_display_name']?.toString() ?? 'Vibe User',
      visitorUsername: _nullableText(json['visitor_username']),
      visitorAvatarUrl: _nullableText(json['visitor_avatar_url']),
      visitorRoleLabel: json['visitor_role_label']?.toString() ?? 'User',
      visitedAt: _date(json['visited_at']) ?? DateTime.now(),
      visitCount: _int(json['visit_count'], fallback: 1),
    );
  }
}

class ProfileRelationshipRealtimeEvent {
  const ProfileRelationshipRealtimeEvent({
    required this.viewerPublicUserId,
    required this.targetPublicUserId,
    required this.action,
  });
  final int viewerPublicUserId;
  final int targetPublicUserId;
  final String action;
  bool touchesProfile(int publicUserId) =>
      viewerPublicUserId == publicUserId || targetPublicUserId == publicUserId;
}

class ProfileRelationshipRealtimeService {
  ProfileRelationshipRealtimeService._();
  static final ProfileRelationshipRealtimeService instance =
      ProfileRelationshipRealtimeService._();
  final StreamController<ProfileRelationshipRealtimeEvent> _controller =
      StreamController<ProfileRelationshipRealtimeEvent>.broadcast();
  Stream<ProfileRelationshipRealtimeEvent> get events => _controller.stream;
  void publish({
    required int viewerPublicUserId,
    required int targetPublicUserId,
    required String action,
  }) {
    if (viewerPublicUserId <= 0 || targetPublicUserId <= 0) return;
    _controller.add(
      ProfileRelationshipRealtimeEvent(
        viewerPublicUserId: viewerPublicUserId,
        targetPublicUserId: targetPublicUserId,
        action: action,
      ),
    );
  }
}

class PublicUserProfile {
  const PublicUserProfile({
    required this.publicUserId,
    required this.displayCustomId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    required this.coverPhotoUrls,
    required this.dateOfBirth,
    required this.gender,
    required this.profession,
    required this.maritalStatus,
    required this.friendGenderPreference,
    required this.friendMaritalPreference,
    required this.interests,
    required this.primaryRole,
    required this.primaryRoleBadge,
    required this.roleBadges,
    required this.vip,
    required this.wallet,
    required this.isOnline,
    required this.lastSeenAt,
    required this.createdAt,
    required this.relationship,
  });

  final int publicUserId;
  final int? displayCustomId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final List<String> coverPhotoUrls;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? profession;
  final String? maritalStatus;
  final String? friendGenderPreference;
  final String? friendMaritalPreference;
  final List<String> interests;
  final String primaryRole;
  final RoleBadge? primaryRoleBadge;
  final List<RoleBadge> roleBadges;
  final UserVipSummary vip;
  final UserWalletSummary wallet;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final DateTime createdAt;
  final UserRelationship? relationship;

  factory PublicUserProfile.fromJson(Map<String, dynamic> json) {
    final primaryRole = json['primary_role']?.toString() ?? 'user';
    final primaryBadgeJson = json['primary_role_badge'];
    final roleBadgesJson = json['role_badges'];
    final relationshipJson = json['relationship'];
    return PublicUserProfile(
      publicUserId: _int(json['public_user_id'], fallback: 0),
      displayCustomId: _nullableInt(json['display_custom_id']),
      username: _nullableText(json['username']),
      displayName: _nullableText(json['display_name']),
      avatarUrl: _nullableText(json['avatar_url']),
      bio: _nullableText(json['bio']),
      coverPhotoUrls: _stringList(json['cover_photo_urls']),
      dateOfBirth: _date(json['date_of_birth']),
      gender: _nullableText(json['gender']),
      profession: _nullableText(json['profession']),
      maritalStatus: _nullableText(json['marital_status']),
      friendGenderPreference: _nullableText(json['friend_gender_preference']),
      friendMaritalPreference: _nullableText(json['friend_marital_preference']),
      interests: _stringList(json['interests']),
      primaryRole: primaryRole,
      primaryRoleBadge: primaryBadgeJson is Map<String, dynamic>
          ? RoleBadge.fromJson(primaryBadgeJson)
          : RoleBadge.fromRole(primaryRole),
      roleBadges: roleBadgesJson is List
          ? roleBadgesJson
                .whereType<Map<String, dynamic>>()
                .map(RoleBadge.fromJson)
                .toList(growable: false)
          : <RoleBadge>[RoleBadge.fromRole(primaryRole)],
      vip: UserVipSummary.fromJson(
        json['vip'] is Map<String, dynamic>
            ? json['vip'] as Map<String, dynamic>
            : null,
      ),
      wallet: UserWalletSummary.fromJson(
        json['wallet'] is Map<String, dynamic>
            ? json['wallet'] as Map<String, dynamic>
            : null,
      ),
      isOnline: json['is_online'] == true,
      lastSeenAt: _date(json['last_seen_at']),
      createdAt: _date(json['created_at']) ?? DateTime.now(),
      relationship: relationshipJson is Map<String, dynamic>
          ? UserRelationship.fromJson(relationshipJson)
          : null,
    );
  }

  int? get age {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final today = DateTime.now();
    var computed = today.year - dob.year;
    final birthdayPassed =
        today.month > dob.month ||
        (today.month == dob.month && today.day >= dob.day);
    if (!birthdayPassed) computed--;
    return computed.clamp(0, 120);
  }

  String get visibleName => displayName ?? username ?? 'Vibe User';
  String get visibleId =>
      displayCustomId?.toString() ?? publicUserId.toString();
}

class UserRelationship {
  const UserRelationship({
    required this.publicUserId,
    required this.isFollowing,
    required this.followsMe,
    required this.isFriend,
    required this.blockedByMe,
    required this.blockedMe,
    required this.canFollow,
    required this.followBlockReason,
    required this.followersCount,
    required this.followingCount,
  });
  final int publicUserId;
  final bool isFollowing;
  final bool followsMe;
  final bool isFriend;
  final bool blockedByMe;
  final bool blockedMe;
  final bool canFollow;
  final String? followBlockReason;
  final int followersCount;
  final int followingCount;
  factory UserRelationship.fromJson(Map<String, dynamic> json) =>
      UserRelationship(
        publicUserId: _int(json['public_user_id'], fallback: 0),
        isFollowing: json['is_following'] == true,
        followsMe: json['follows_me'] == true,
        isFriend: json['is_friend'] == true,
        blockedByMe: json['blocked_by_me'] == true,
        blockedMe: json['blocked_me'] == true,
        canFollow: json['can_follow'] != false,
        followBlockReason: _nullableText(json['follow_block_reason']),
        followersCount: _int(json['followers_count'], fallback: 0),
        followingCount: _int(json['following_count'], fallback: 0),
      );
}

dynamic _tryDecodeJson(String body) {
  try {
    return jsonDecode(body);
  } catch (_) {
    return null;
  }
}

int _int(dynamic value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _nullableText(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

List<String> _stringList(dynamic value) => value is List
    ? value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
    : const [];
DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty)
    return DateTime.tryParse(value);
  return null;
}
