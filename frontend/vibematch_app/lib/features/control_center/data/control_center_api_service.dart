import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api_service.dart';

class ControlCenterApiService {
  ControlCenterApiService({ApiClient? apiClient, AuthApiService? authApiService})
      : _apiClient = apiClient ?? ApiClient(),
        _authApiService = authApiService ?? const AuthApiService();

  final ApiClient _apiClient;
  final AuthApiService _authApiService;

  Future<AdminControlSummary> loadSummary() async {
    final json = await _apiClient.getMap('/admin/control-summary', headers: _headers());
    return AdminControlSummary.fromJson(json);
  }

  Future<List<AdminUser>> loadUsers() async {
    final json = await _apiClient.getList('/admin/users', headers: _headers());
    return json.whereType<Map<String, dynamic>>().map(AdminUser.fromJson).toList(growable: false);
  }

  Future<List<RoleOption>> loadRoleOptions() async {
    final json = await _apiClient.getList('/admin/role-options', headers: _headers());
    return json.whereType<Map<String, dynamic>>().map(RoleOption.fromJson).toList(growable: false);
  }

  Future<void> assignRole({required int targetUserId, required String role, required String reason}) async {
    await _apiClient.postMap(
      '/admin/roles/assign',
      headers: _headers(),
      body: {'target_user_id': targetUserId, 'role': role, 'reason': reason},
    );
  }

  Future<void> banUser({required int targetUserId, required String reason, String? deviceId}) async {
    await _apiClient.postMap(
      '/moderation/users/ban',
      headers: _headers(),
      body: {
        'target_user_id': targetUserId,
        'reason': reason,
        if (deviceId != null && deviceId.trim().isNotEmpty) 'device_id': deviceId.trim(),
      },
    );
  }

  Future<void> unbanUser({required int targetUserId, required String reason}) async {
    await _apiClient.postMap(
      '/moderation/users/unban',
      headers: _headers(),
      body: {'target_user_id': targetUserId, 'reason': reason},
    );
  }

  Future<List<UserBanItem>> loadUserBans() async {
    final json = await _apiClient.getList('/moderation/users/bans', headers: _headers());
    return json.whereType<Map<String, dynamic>>().map(UserBanItem.fromJson).toList(growable: false);
  }

  Future<List<DeviceBanItem>> loadDeviceBans() async {
    final json = await _apiClient.getList('/moderation/devices/bans', headers: _headers());
    return json.whereType<Map<String, dynamic>>().map(DeviceBanItem.fromJson).toList(growable: false);
  }

  Future<void> unbanDevice({required String deviceId, required String reason}) async {
    await _apiClient.postMap(
      '/moderation/devices/unban',
      headers: _headers(),
      body: {'device_id': deviceId, 'reason': reason},
    );
  }

  Map<String, String> _headers() {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before opening Control Center.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  void close() => _apiClient.close();
}

class AdminControlSummary {
  const AdminControlSummary({
    required this.currentUserId,
    required this.currentPrimaryRole,
    required this.canAssignRoles,
    required this.canViewAuditLogs,
    required this.canViewLoginHistory,
    required this.usersCount,
    required this.activeUsersCount,
    required this.bannedUsersCount,
    required this.officialUsersCount,
    required this.recentAuditCount,
  });

  final int currentUserId;
  final String currentPrimaryRole;
  final bool canAssignRoles;
  final bool canViewAuditLogs;
  final bool canViewLoginHistory;
  final int usersCount;
  final int activeUsersCount;
  final int bannedUsersCount;
  final int officialUsersCount;
  final int recentAuditCount;

  bool get isSuperOwnerPanel => currentPrimaryRole == 'founder_owner';
  bool get isOwnerPanel => currentPrimaryRole == 'owner';
  bool get isSuperAdminPanel => currentPrimaryRole == 'superadmin';

  factory AdminControlSummary.fromJson(Map<String, dynamic> json) {
    return AdminControlSummary(
      currentUserId: _int(json['current_user_id']),
      currentPrimaryRole: json['current_primary_role']?.toString() ?? 'user',
      canAssignRoles: json['can_assign_roles'] == true,
      canViewAuditLogs: json['can_view_audit_logs'] == true,
      canViewLoginHistory: json['can_view_login_history'] == true,
      usersCount: _int(json['users_count']),
      activeUsersCount: _int(json['active_users_count']),
      bannedUsersCount: _int(json['banned_users_count']),
      officialUsersCount: _int(json['official_users_count']),
      recentAuditCount: _int(json['recent_audit_count']),
    );
  }
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.publicUserId,
    required this.displayName,
    required this.username,
    required this.isActive,
    required this.isBanned,
    required this.roles,
    required this.primaryRole,
    this.displayCustomId,
  });

  final int id;
  final int publicUserId;
  final int? displayCustomId;
  final String displayName;
  final String username;
  final bool isActive;
  final bool isBanned;
  final List<String> roles;
  final String primaryRole;

  String get title => displayName.trim().isNotEmpty ? displayName : username;
  String get roleLabel => primaryRole.replaceAll('_', ' ').toUpperCase();
  bool get isNormalUser => primaryRole == 'user';
  bool get isProtectedOfficial => primaryRole == 'founder_owner' || primaryRole == 'owner' || primaryRole == 'superadmin' || primaryRole == 'admin' || primaryRole == 'monitor' || primaryRole == 'cs';

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final username = json['username']?.toString() ?? 'user_${json['public_user_id']}';
    final displayName = json['display_name']?.toString() ?? username;
    final rolesRaw = json['roles'];
    return AdminUser(
      id: _int(json['id']),
      publicUserId: _int(json['public_user_id']),
      displayCustomId: json['display_custom_id'] == null ? null : _int(json['display_custom_id']),
      displayName: displayName,
      username: username,
      isActive: json['is_active'] != false,
      isBanned: json['is_banned'] == true,
      roles: rolesRaw is List ? rolesRaw.map((item) => item.toString()).toList(growable: false) : const <String>[],
      primaryRole: json['primary_role']?.toString() ?? 'user',
    );
  }
}

class RoleOption {
  const RoleOption({required this.value, required this.label, required this.power, required this.assignable});

  final String value;
  final String label;
  final int power;
  final bool assignable;

  factory RoleOption.fromJson(Map<String, dynamic> json) {
    return RoleOption(
      value: json['value']?.toString() ?? 'user',
      label: json['label']?.toString() ?? 'User',
      power: _int(json['power']),
      assignable: json['assignable'] == true,
    );
  }
}

class UserBanItem {
  const UserBanItem({required this.id, required this.userId, required this.reason, required this.isActive, this.deviceId});

  final int id;
  final int userId;
  final String reason;
  final bool isActive;
  final String? deviceId;

  factory UserBanItem.fromJson(Map<String, dynamic> json) {
    return UserBanItem(
      id: _int(json['id']),
      userId: _int(json['user_id']),
      reason: json['reason']?.toString() ?? 'No reason',
      isActive: json['is_active'] != false,
      deviceId: json['device_id_snapshot']?.toString(),
    );
  }
}

class DeviceBanItem {
  const DeviceBanItem({required this.id, required this.deviceId, required this.reason, required this.isActive});

  final int id;
  final String deviceId;
  final String reason;
  final bool isActive;

  factory DeviceBanItem.fromJson(Map<String, dynamic> json) {
    return DeviceBanItem(
      id: _int(json['id']),
      deviceId: json['device_id']?.toString() ?? '',
      reason: json['reason']?.toString() ?? 'No reason',
      isActive: json['is_active'] != false,
    );
  }
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
