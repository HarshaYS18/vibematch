import '../../../auth/models/current_user.dart';
import '../../../auth/models/role_badge.dart';

class ProfileQrPayload {
  const ProfileQrPayload({
    required this.publicUserId,
    required this.displayCustomId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.primaryRole,
  });

  static const String scheme = 'vibematch';
  static const String host = 'profile';
  static const String version = '1';

  final int publicUserId;
  final int? displayCustomId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String primaryRole;

  factory ProfileQrPayload.fromUser(CurrentUser user) {
    return ProfileQrPayload(
      publicUserId: user.publicUserId,
      displayCustomId: user.displayCustomId,
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      primaryRole: user.primaryRole,
    );
  }

  String get visibleId => displayCustomId?.toString() ?? publicUserId.toString();

  String get titleName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) return handle;
    return 'Vibe User';
  }

  String toQrValue() {
    return Uri(
      scheme: scheme,
      host: host,
      queryParameters: <String, String>{
        'v': version,
        'public_user_id': publicUserId.toString(),
        if (displayCustomId != null) 'display_custom_id': displayCustomId.toString(),
        if (username != null && username!.trim().isNotEmpty) 'username': username!.trim(),
        if (displayName != null && displayName!.trim().isNotEmpty) 'display_name': displayName!.trim(),
        if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) 'avatar_url': avatarUrl!.trim(),
        'primary_role': primaryRole.trim().isEmpty ? 'user' : primaryRole.trim(),
      },
    ).toString();
  }

  CurrentUser toResolvedUser() {
    final now = DateTime.now();
    final role = primaryRole.trim().isEmpty ? 'user' : primaryRole.trim();
    final roleBadge = RoleBadge.fromRole(role);

    return CurrentUser(
      id: publicUserId,
      publicUserId: publicUserId,
      displayCustomId: displayCustomId,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      bio: null,
      dateOfBirth: null,
      gender: null,
      profession: null,
      maritalStatus: null,
      friendGenderPreference: null,
      friendMaritalPreference: null,
      interests: const [],
      roles: <String>[role],
      primaryRole: role,
      primaryRoleBadge: roleBadge,
      roleBadges: [roleBadge],
      isActive: true,
      isBanned: false,
      lastDeviceId: null,
      lastLoginAt: null,
      lastSeenAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  static ProfileQrPayload? tryParse(String? rawValue) {
    if (rawValue == null) return null;

    final text = rawValue.trim();
    if (text.isEmpty) return null;

    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != scheme || uri.host != host) return null;

    final publicUserId = int.tryParse(uri.queryParameters['public_user_id'] ?? '');
    if (publicUserId == null || publicUserId <= 0) return null;

    return ProfileQrPayload(
      publicUserId: publicUserId,
      displayCustomId: int.tryParse(uri.queryParameters['display_custom_id'] ?? ''),
      username: _clean(uri.queryParameters['username']),
      displayName: _clean(uri.queryParameters['display_name']),
      avatarUrl: _clean(uri.queryParameters['avatar_url']),
      primaryRole: _clean(uri.queryParameters['primary_role']) ?? 'user',
    );
  }

  static String? _clean(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
