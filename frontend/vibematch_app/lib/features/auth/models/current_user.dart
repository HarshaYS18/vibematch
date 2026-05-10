import '../../profile/models/vip_wallet_models.dart';
import 'role_badge.dart';

class CurrentUser {
  final int id;
  final int publicUserId;
  final int? displayCustomId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final List<String> roles;
  final String primaryRole;
  final RoleBadge? primaryRoleBadge;
  final List<RoleBadge> roleBadges;
  final UserVipSummary vip;
  final UserWalletSummary wallet;
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
    required this.roles,
    required this.primaryRole,
    required this.primaryRoleBadge,
    required this.roleBadges,
    this.vip = const UserVipSummary.empty(),
    this.wallet = const UserWalletSummary.empty(),
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
    final rolesValue = json['roles'];
    final parsedRoles = rolesValue is List ? rolesValue.map((role) => role.toString()).toList() : <String>['user'];
    final primaryRoleValue = json['primary_role'];
    final primaryRole = primaryRoleValue == null || primaryRoleValue.toString().trim().isEmpty ? parsedRoles.first : primaryRoleValue.toString();
    final primaryBadgeJson = json['primary_role_badge'] ?? json['primaryRoleBadge'];
    final roleBadgesJson = json['role_badges'] ?? json['roleBadges'];
    final parsedRoleBadges = roleBadgesJson is List
        ? roleBadgesJson.whereType<Map<String, dynamic>>().map(RoleBadge.fromJson).toList()
        : <RoleBadge>[];

    return CurrentUser(
      id: _intFromJson(json, keys: const ['id', 'user_id'], fallback: 0),
      publicUserId: _intFromJson(json, keys: const ['public_user_id', 'publicUserId'], fallback: 6418000000),
      displayCustomId: _nullableIntFromJson(json, keys: const ['display_custom_id', 'displayCustomId']),
      username: _nullableStringFromJson(json, keys: const ['username']),
      displayName: _nullableStringFromJson(json, keys: const ['display_name', 'displayName']),
      avatarUrl: _nullableStringFromJson(json, keys: const ['avatar_url', 'avatarUrl']),
      roles: parsedRoles.isEmpty ? <String>['user'] : parsedRoles,
      primaryRole: primaryRole,
      primaryRoleBadge: primaryBadgeJson is Map<String, dynamic> ? RoleBadge.fromJson(primaryBadgeJson) : RoleBadge.fromRole(primaryRole),
      roleBadges: parsedRoleBadges.isEmpty ? [RoleBadge.fromRole(primaryRole)] : parsedRoleBadges,
      vip: UserVipSummary.fromJson(json['vip'] is Map<String, dynamic> ? json['vip'] as Map<String, dynamic> : null),
      wallet: UserWalletSummary.fromJson(json['wallet'] is Map<String, dynamic> ? json['wallet'] as Map<String, dynamic> : null),
      isActive: _boolFromJson(json, keys: const ['is_active', 'isActive'], fallback: true),
      isBanned: _boolFromJson(json, keys: const ['is_banned', 'isBanned'], fallback: false),
      lastDeviceId: _nullableStringFromJson(json, keys: const ['last_device_id', 'lastDeviceId']),
      lastLoginAt: _dateTimeFromJson(json, keys: const ['last_login_at', 'lastLoginAt']),
      lastSeenAt: _dateTimeFromJson(json, keys: const ['last_seen_at', 'lastSeenAt']),
      createdAt: _dateTimeFromJson(json, keys: const ['created_at', 'createdAt']) ?? now,
      updatedAt: _dateTimeFromJson(json, keys: const ['updated_at', 'updatedAt']) ?? now,
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
      roles: const ['founder_owner', 'owner', 'superadmin', 'admin', 'monitor', 'cs', 'user'],
      primaryRole: 'founder_owner',
      primaryRoleBadge: badge,
      roleBadges: [badge],
      vip: const UserVipSummary(vipLevel: 50, svipLevel: 10, vipIsActive: true, svipIsActive: true, svipExpiresAt: null, nameGradientKey: 'svip_10_founder_glow', nameGradientColors: ['#FFD700', '#FFFFFF', '#7F00FF', '#00F5FF']),
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

  CurrentUser copyWith({
    int? id,
    int? publicUserId,
    int? displayCustomId,
    String? username,
    String? displayName,
    String? avatarUrl,
    List<String>? roles,
    String? primaryRole,
    RoleBadge? primaryRoleBadge,
    List<RoleBadge>? roleBadges,
    UserVipSummary? vip,
    UserWalletSummary? wallet,
    bool? isActive,
    bool? isBanned,
    String? lastDeviceId,
    DateTime? lastLoginAt,
    DateTime? lastSeenAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearDisplayCustomId = false,
    bool clearAvatarUrl = false,
    bool clearLastDeviceId = false,
    bool clearLastLoginAt = false,
    bool clearLastSeenAt = false,
  }) {
    return CurrentUser(
      id: id ?? this.id,
      publicUserId: publicUserId ?? this.publicUserId,
      displayCustomId: clearDisplayCustomId ? null : displayCustomId ?? this.displayCustomId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: clearAvatarUrl ? null : avatarUrl ?? this.avatarUrl,
      roles: roles ?? this.roles,
      primaryRole: primaryRole ?? this.primaryRole,
      primaryRoleBadge: primaryRoleBadge ?? this.primaryRoleBadge,
      roleBadges: roleBadges ?? this.roleBadges,
      vip: vip ?? this.vip,
      wallet: wallet ?? this.wallet,
      isActive: isActive ?? this.isActive,
      isBanned: isBanned ?? this.isBanned,
      lastDeviceId: clearLastDeviceId ? null : lastDeviceId ?? this.lastDeviceId,
      lastLoginAt: clearLastLoginAt ? null : lastLoginAt ?? this.lastLoginAt,
      lastSeenAt: clearLastSeenAt ? null : lastSeenAt ?? this.lastSeenAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int _intFromJson(Map<String, dynamic> json, {required List<String> keys, required int fallback}) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  static int? _nullableIntFromJson(Map<String, dynamic> json, {required List<String> keys}) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
    }
    return null;
  }

  static bool _boolFromJson(Map<String, dynamic> json, {required List<String> keys, required bool fallback}) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1' || normalized == 'yes') return true;
        if (normalized == 'false' || normalized == '0' || normalized == 'no') return false;
      }
    }
    return fallback;
  }

  static String? _nullableStringFromJson(Map<String, dynamic> json, {required List<String> keys}) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static DateTime? _dateTimeFromJson(Map<String, dynamic> json, {required List<String> keys}) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is DateTime) return value;
      if (value is String && value.trim().isNotEmpty) return DateTime.tryParse(value);
    }
    return null;
  }

  String get visibleId => displayCustomId?.toString() ?? publicUserId.toString();
  bool get isFounderOwner => primaryRole == 'founder_owner';
  bool get isOwner => primaryRole == 'owner';
  bool get isNormalUser => primaryRole == 'user' && roles.length == 1 && roles.contains('user');
  bool get canSeeFounderControls => isFounderOwner;
  bool get canSeeOwnerControls => primaryRole == 'founder_owner' || primaryRole == 'owner';
  bool get isOfficialOrStaff => roles.any((role) => {'founder_owner', 'owner', 'superadmin', 'admin', 'monitor', 'cs'}.contains(role));
  bool get shouldShowOfficialYellowTick => primaryRoleBadge?.showVerifiedTick == true || primaryRole == 'founder_owner' || primaryRole == 'super_owner' || primaryRole == 'owner';

  String get accountStatusLabel {
    if (isBanned) return 'Banned';
    if (!isActive) return 'Inactive';
    return 'Active';
  }

  String get lastLoginLabel => lastLoginAt == null ? 'Never' : lastLoginAt!.toLocal().toString();
  String get roleDisplayLabel => primaryRoleBadge?.displayTitle ?? RoleBadge.fromRole(primaryRole).displayTitle;
  String? get rolePillLabel => primaryRoleBadge?.pillLabel;
}
