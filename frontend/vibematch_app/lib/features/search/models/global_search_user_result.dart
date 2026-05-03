class GlobalSearchUserResult {
  const GlobalSearchUserResult({
    required this.id,
    required this.publicUserId,
    required this.displayCustomId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.primaryRole,
    required this.roles,
    required this.isActive,
  });

  final int id;
  final int publicUserId;
  final int? displayCustomId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String primaryRole;
  final List<String> roles;
  final bool isActive;

  factory GlobalSearchUserResult.fromJson(Map<String, dynamic> json) {
    final rolesValue = json['roles'];
    final parsedRoles = rolesValue is List
        ? rolesValue.map((role) => role.toString()).toList(growable: false)
        : <String>['user'];

    return GlobalSearchUserResult(
      id: _intFromJson(json['id']),
      publicUserId: _intFromJson(json['public_user_id'] ?? json['publicUserId']),
      displayCustomId: _nullableIntFromJson(json['display_custom_id'] ?? json['displayCustomId']),
      username: _nullableString(json['username']),
      displayName: _nullableString(json['display_name'] ?? json['displayName']),
      avatarUrl: _nullableString(json['avatar_url'] ?? json['avatarUrl']),
      primaryRole: (json['primary_role'] ?? json['primaryRole'] ?? 'user').toString(),
      roles: parsedRoles.isEmpty ? const ['user'] : parsedRoles,
      isActive: _boolFromJson(json['is_active'] ?? json['isActive'], fallback: true),
    );
  }

  String get visibleName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) return handle;

    return 'Vibe User';
  }

  String get visibleId => displayCustomId?.toString() ?? publicUserId.toString();

  String get subtitle {
    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) {
      return '@$handle · ID $visibleId';
    }
    return 'ID $visibleId';
  }

  bool get isOfficialOrStaff {
    return roles.any(
      (role) => {
        'founder_owner',
        'super_owner',
        'owner',
        'superadmin',
        'admin',
        'monitor',
        'cs',
      }.contains(role),
    );
  }

  bool get shouldShowOfficialTick {
    return primaryRole == 'founder_owner' || primaryRole == 'super_owner' || primaryRole == 'owner';
  }

  String get roleLabel {
    switch (primaryRole) {
      case 'founder_owner':
        return 'Founder Owner';
      case 'super_owner':
        return 'Super Owner';
      case 'owner':
        return 'Owner';
      case 'superadmin':
        return 'SuperAdmin';
      case 'admin':
        return 'Admin';
      case 'monitor':
        return 'Monitor';
      case 'cs':
        return 'CS';
      default:
        return 'User';
    }
  }

  static int _intFromJson(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static int? _nullableIntFromJson(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static bool _boolFromJson(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') return true;
      if (normalized == 'false' || normalized == '0' || normalized == 'no') return false;
    }
    return fallback;
  }
}
