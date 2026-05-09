import 'role_badge.dart';

class AuthResponse {
  final String accessToken;
  final String tokenType;
  final int userId;
  final int publicUserId;
  final List<String> roles;
  final String primaryRole;
  final RoleBadge? primaryRoleBadge;
  final List<RoleBadge> roleBadges;

  AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.userId,
    required this.publicUserId,
    required this.roles,
    required this.primaryRole,
    required this.primaryRoleBadge,
    required this.roleBadges,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final rolesValue = json['roles'];
    final parsedRoles = rolesValue is List
        ? rolesValue.map((role) => role.toString()).toList()
        : <String>['user'];

    final primaryRoleValue = json['primary_role'] ?? json['primaryRole'];
    final primaryRole = primaryRoleValue == null || primaryRoleValue.toString().trim().isEmpty
        ? (parsedRoles.isEmpty ? 'user' : parsedRoles.first)
        : primaryRoleValue.toString();

    final primaryBadgeJson = json['primary_role_badge'] ?? json['primaryRoleBadge'];
    final roleBadgesJson = json['role_badges'] ?? json['roleBadges'];
    final parsedRoleBadges = roleBadgesJson is List
        ? roleBadgesJson.whereType<Map<String, dynamic>>().map(RoleBadge.fromJson).toList()
        : <RoleBadge>[];

    return AuthResponse(
      accessToken: json['access_token'] as String,
      tokenType: (json['token_type'] ?? 'bearer') as String,
      userId: json['user_id'] as int,
      publicUserId: json['public_user_id'] as int,
      roles: parsedRoles.isEmpty ? <String>['user'] : parsedRoles,
      primaryRole: primaryRole,
      primaryRoleBadge: primaryBadgeJson is Map<String, dynamic> ? RoleBadge.fromJson(primaryBadgeJson) : RoleBadge.fromRole(primaryRole),
      roleBadges: parsedRoleBadges.isEmpty ? [RoleBadge.fromRole(primaryRole)] : parsedRoleBadges,
    );
  }
}
