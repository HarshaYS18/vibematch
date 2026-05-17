import 'current_user.dart';

CurrentUser currentUserFromMasterStateJson(Map<String, dynamic> json) {
  final identity = json['identity'] is Map<String, dynamic>
      ? json['identity'] as Map<String, dynamic>
      : <String, dynamic>{};
  final rolesJson = json['roles'] is Map<String, dynamic>
      ? json['roles'] as Map<String, dynamic>
      : <String, dynamic>{};
  final profileSummary = json['profile_summary'] is Map<String, dynamic>
      ? json['profile_summary'] as Map<String, dynamic>
      : <String, dynamic>{};

  return CurrentUser.fromJson(<String, dynamic>{
    ...identity,
    'id': identity['backend_user_id'] ?? identity['user_id'] ?? identity['id'],
    'public_user_id': identity['public_user_id'],
    'display_custom_id': identity['display_custom_id'],
    'username': identity['username'],
    'display_name': identity['display_name'],
    'avatar_url': identity['avatar_url'],
    'bio': identity['bio'],
    'roles': rolesJson['roles'],
    'primary_role': rolesJson['primary_role'],
    'primary_role_badge': rolesJson['primary_role_badge'],
    'role_badges': rolesJson['role_badges'],
    'vip': profileSummary['vip'] ?? json['vip'],
    'wallet': profileSummary['wallet'] ?? json['wallet'],
    'is_active': identity['is_active'],
    'is_banned': identity['is_banned'],
    'last_seen_at': identity['last_seen_at'],
    'created_at': identity['created_at'],
    'updated_at': identity['updated_at'],
  });
}
