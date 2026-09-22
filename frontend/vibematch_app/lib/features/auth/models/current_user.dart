import '../../profile/models/vip_wallet_models.dart';
import 'role_badge.dart';
import 'user_identity_snapshot.dart';

class CurrentUser {
  final int id;
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
  final List<String> roles;
  final String primaryRole;
  final RoleBadge? primaryRoleBadge;
  final List<RoleBadge> roleBadges;
  final UserVipSummary vip;
  final UserWalletSummary wallet;
  final bool profileSetupCompleted;
  final bool isActive;
  final bool isBanned;
  final String? lastDeviceId;
  final DateTime? lastLoginAt;
  final DateTime? lastSeenAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  CurrentUser({
    required this.id,
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
    required this.roles,
    required this.primaryRole,
    required this.primaryRoleBadge,
    required this.roleBadges,
    this.vip = const UserVipSummary.empty(),
    this.wallet = const UserWalletSummary.empty(),
    this.profileSetupCompleted = false,
    required this.isActive,
    required this.isBanned,
    required this.lastDeviceId,
    required this.lastLoginAt,
    required this.lastSeenAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final identity = UserIdentitySnapshot.fromJson(json);
    final rolesValue = json['roles'];
    final parsedRoles = rolesValue is List
        ? rolesValue
              .map((role) => role.toString().trim())
              .where((role) => role.isNotEmpty)
              .toList(growable: false)
        : <String>[];
    final roles = parsedRoles.isEmpty
        ? <String>[identity.primaryRole]
        : parsedRoles;
    final primaryBadge =
        identity.primaryRoleBadge ?? RoleBadge.fromRole(identity.primaryRole);
    final badges = identity.roleBadges.isEmpty
        ? <RoleBadge>[primaryBadge]
        : identity.roleBadges;

    return CurrentUser(
      id: identity.backendUserId,
      publicUserId: identity.publicUserId,
      displayCustomId: identity.displayCustomId,
      username: identity.username,
      displayName: identity.displayName,
      avatarUrl: identity.avatarUrl,
      bio: _nullableStringFromJson(json, keys: const ['bio']),
      coverPhotoUrls: _stringListFromJson(
        json,
        keys: const ['cover_photo_urls', 'coverPhotoUrls'],
      ),
      dateOfBirth: _dateTimeFromJson(
        json,
        keys: const ['date_of_birth', 'dateOfBirth'],
      ),
      gender: _nullableStringFromJson(json, keys: const ['gender']),
      profession: _nullableStringFromJson(json, keys: const ['profession']),
      maritalStatus: _nullableStringFromJson(
        json,
        keys: const ['marital_status', 'maritalStatus'],
      ),
      friendGenderPreference: _nullableStringFromJson(
        json,
        keys: const ['friend_gender_preference', 'friendGenderPreference'],
      ),
      friendMaritalPreference: _nullableStringFromJson(
        json,
        keys: const ['friend_marital_preference', 'friendMaritalPreference'],
      ),
      interests: _stringListFromJson(json, keys: const ['interests']),
      roles: roles,
      primaryRole: identity.primaryRole,
      primaryRoleBadge: primaryBadge,
      roleBadges: badges,
      vip: identity.vip,
      wallet: UserWalletSummary.fromJson(
        json['wallet'] is Map
            ? (json['wallet'] as Map).cast<String, dynamic>()
            : null,
      ),
      profileSetupCompleted: _boolFromJson(
        json,
        keys: const ['profile_setup_completed', 'profileSetupCompleted'],
        fallback:
            identity.displayName?.trim().isNotEmpty == true &&
            identity.avatarUrl?.trim().isNotEmpty == true,
      ),
      isActive: _boolFromJson(
        json,
        keys: const ['is_active', 'isActive'],
        fallback: true,
      ),
      isBanned: _boolFromJson(
        json,
        keys: const ['is_banned', 'isBanned'],
        fallback: false,
      ),
      lastDeviceId: _nullableStringFromJson(
        json,
        keys: const ['last_device_id', 'lastDeviceId'],
      ),
      lastLoginAt: _dateTimeFromJson(
        json,
        keys: const ['last_login_at', 'lastLoginAt'],
      ),
      lastSeenAt: _dateTimeFromJson(
        json,
        keys: const ['last_seen_at', 'lastSeenAt'],
      ),
      createdAt:
          _dateTimeFromJson(
            json,
            keys: const ['created_at', 'createdAt'],
          ) ??
          now,
      updatedAt:
          _dateTimeFromJson(
            json,
            keys: const ['updated_at', 'updatedAt'],
          ) ??
          now,
    );
  }

  factory CurrentUser.mockFounderOwner() {
    final now = DateTime.now();
    final badge = RoleBadge.fromRole('founder_owner');
    return CurrentUser(
      id: 1,
      publicUserId: 6922022,
      displayCustomId: 6922022,
      username: 'founder',
      displayName: 'Harsha',
      avatarUrl: null,
      bio: null,
      coverPhotoUrls: const [],
      dateOfBirth: null,
      gender: null,
      profession: null,
      maritalStatus: null,
      friendGenderPreference: null,
      friendMaritalPreference: null,
      interests: const [],
      roles: const [
        'founder_owner',
        'owner',
        'superadmin',
        'admin',
        'monitor',
        'cs',
        'user',
      ],
      primaryRole: 'founder_owner',
      primaryRoleBadge: badge,
      roleBadges: [badge],
      vip: const UserVipSummary(
        vipLevel: 50,
        svipLevel: 10,
        vipIsActive: true,
        svipIsActive: true,
        svipExpiresAt: null,
        nameGradientKey: 'svip_10_founder_glow',
        nameGradientColors: ['#FFD700', '#FFFFFF', '#7F00FF', '#00F5FF'],
      ),
      wallet: const UserWalletSummary.empty(),
      isActive: true,
      isBanned: false,
      lastDeviceId: 'mock-founder-device',
      lastLoginAt: now,
      lastSeenAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory CurrentUser.mockNormalUser() {
    final now = DateTime.now();
    final badge = RoleBadge.fromRole('user');
    return CurrentUser(
      id: 2,
      publicUserId: 6418001245,
      displayCustomId: null,
      username: 'riya_vibes',
      displayName: 'Riya Sharma',
      avatarUrl: null,
      bio: null,
      coverPhotoUrls: const [],
      dateOfBirth: null,
      gender: null,
      profession: null,
      maritalStatus: null,
      friendGenderPreference: null,
      friendMaritalPreference: null,
      interests: const [],
      roles: const ['user'],
      primaryRole: 'user',
      primaryRoleBadge: badge,
      roleBadges: [badge],
      vip: const UserVipSummary.empty(),
      wallet: const UserWalletSummary.empty(),
      isActive: true,
      isBanned: false,
      lastDeviceId: 'mock-user-device',
      lastLoginAt: now,
      lastSeenAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'public_user_id': publicUserId,
      'display_custom_id': displayCustomId,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'cover_photo_urls': coverPhotoUrls,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'profession': profession,
      'marital_status': maritalStatus,
      'friend_gender_preference': friendGenderPreference,
      'friend_marital_preference': friendMaritalPreference,
      'interests': interests,
      'roles': roles,
      'primary_role': primaryRole,
      'primary_role_badge': primaryRoleBadge?.toJson(),
      'role_badges': roleBadges
          .map((badge) => badge.toJson())
          .toList(growable: false),
      'vip': vip.toJson(),
      'wallet': wallet.toJson(),
      'profile_setup_completed': profileSetupCompleted,
      'is_active': isActive,
      'is_banned': isBanned,
      'last_device_id': lastDeviceId,
      'last_login_at': lastLoginAt?.toIso8601String(),
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CurrentUser copyWith({
    int? id,
    int? publicUserId,
    int? displayCustomId,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    List<String>? coverPhotoUrls,
    DateTime? dateOfBirth,
    String? gender,
    String? profession,
    String? maritalStatus,
    String? friendGenderPreference,
    String? friendMaritalPreference,
    List<String>? interests,
    List<String>? roles,
    String? primaryRole,
    RoleBadge? primaryRoleBadge,
    List<RoleBadge>? roleBadges,
    UserVipSummary? vip,
    UserWalletSummary? wallet,
    bool? profileSetupCompleted,
    bool? isActive,
    bool? isBanned,
    String? lastDeviceId,
    DateTime? lastLoginAt,
    DateTime? lastSeenAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearDisplayCustomId = false,
    bool clearAvatarUrl = false,
    bool clearBio = false,
    bool clearCoverPhotoUrls = false,
    bool clearDateOfBirth = false,
    bool clearLastDeviceId = false,
    bool clearLastLoginAt = false,
    bool clearLastSeenAt = false,
  }) {
    return CurrentUser(
      id: id ?? this.id,
      publicUserId: publicUserId ?? this.publicUserId,
      displayCustomId: clearDisplayCustomId
          ? null
          : displayCustomId ?? this.displayCustomId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: clearAvatarUrl ? null : avatarUrl ?? this.avatarUrl,
      bio: clearBio ? null : bio ?? this.bio,
      coverPhotoUrls: clearCoverPhotoUrls
          ? const []
          : coverPhotoUrls ?? this.coverPhotoUrls,
      dateOfBirth: clearDateOfBirth ? null : dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      profession: profession ?? this.profession,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      friendGenderPreference:
          friendGenderPreference ?? this.friendGenderPreference,
      friendMaritalPreference:
          friendMaritalPreference ?? this.friendMaritalPreference,
      interests: interests ?? this.interests,
      roles: roles ?? this.roles,
      primaryRole: primaryRole ?? this.primaryRole,
      primaryRoleBadge: primaryRoleBadge ?? this.primaryRoleBadge,
      roleBadges: roleBadges ?? this.roleBadges,
      vip: vip ?? this.vip,
      wallet: wallet ?? this.wallet,
      profileSetupCompleted:
          profileSetupCompleted ?? this.profileSetupCompleted,
      isActive: isActive ?? this.isActive,
      isBanned: isBanned ?? this.isBanned,
      lastDeviceId: clearLastDeviceId
          ? null
          : lastDeviceId ?? this.lastDeviceId,
      lastLoginAt: clearLastLoginAt ? null : lastLoginAt ?? this.lastLoginAt,
      lastSeenAt: clearLastSeenAt ? null : lastSeenAt ?? this.lastSeenAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static bool _boolFromJson(
    Map<String, dynamic> json, {
    required List<String> keys,
    required bool fallback,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
          return true;
        }
        if (normalized == 'false' ||
            normalized == '0' ||
            normalized == 'no') {
          return false;
        }
      }
    }
    return fallback;
  }

  static String? _nullableStringFromJson(
    Map<String, dynamic> json, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static List<String> _stringListFromJson(
    Map<String, dynamic> json, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is List) {
        return value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
    }
    return const [];
  }

  static DateTime? _dateTimeFromJson(
    Map<String, dynamic> json, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is DateTime) return value;
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.tryParse(value);
      }
    }
    return null;
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

  String get visibleId =>
      displayCustomId?.toString() ?? publicUserId.toString();
  bool get isFounderOwner => primaryRole == 'founder_owner';
  bool get isOwner => primaryRole == 'owner';
  bool get isNormalUser =>
      primaryRole == 'user' && roles.length == 1 && roles.contains('user');
  bool get canSeeFounderControls => isFounderOwner;
  bool get canSeeOwnerControls =>
      primaryRole == 'founder_owner' || primaryRole == 'owner';
  bool get isOfficialOrStaff => roles.any(
    (role) => {
      'founder_owner',
      'owner',
      'superadmin',
      'admin',
      'monitor',
      'cs',
    }.contains(role),
  );
  bool get shouldShowOfficialYellowTick =>
      primaryRoleBadge?.showVerifiedTick == true ||
      primaryRole == 'founder_owner' ||
      primaryRole == 'super_owner' ||
      primaryRole == 'owner';

  String get accountStatusLabel {
    if (isBanned) return 'Banned';
    if (!isActive) return 'Inactive';
    return 'Active';
  }

  String get lastLoginLabel =>
      lastLoginAt == null ? 'Never' : lastLoginAt!.toLocal().toString();
  String get roleDisplayLabel =>
      primaryRoleBadge?.displayTitle ?? RoleBadge.fromRole(primaryRole).displayTitle;
  String? get rolePillLabel => primaryRoleBadge?.pillLabel;
}
