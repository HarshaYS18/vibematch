import 'dart:convert';

import 'package:http/http.dart' as http;

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

  Future<PublicUserProfile> getPublicProfile(int publicUserId) async {
    final response = await http.get(Uri.parse(VmApiConfig.endpoint('/users/public/$publicUserId')));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load public profile (${response.statusCode}): ${response.body}');
    }
    return PublicUserProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

class PublicUserProfile {
  const PublicUserProfile({
    required this.publicUserId,
    required this.displayCustomId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.primaryRole,
    required this.primaryRoleBadge,
    required this.roleBadges,
    required this.vip,
    required this.isOnline,
    required this.lastSeenAt,
    required this.createdAt,
  });

  final int publicUserId;
  final int? displayCustomId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String primaryRole;
  final RoleBadge? primaryRoleBadge;
  final List<RoleBadge> roleBadges;
  final UserVipSummary vip;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final DateTime createdAt;

  factory PublicUserProfile.fromJson(Map<String, dynamic> json) {
    final primaryRole = json['primary_role']?.toString() ?? 'user';
    final primaryBadgeJson = json['primary_role_badge'];
    final roleBadgesJson = json['role_badges'];
    return PublicUserProfile(
      publicUserId: _int(json['public_user_id'], fallback: 0),
      displayCustomId: _nullableInt(json['display_custom_id']),
      username: _nullableText(json['username']),
      displayName: _nullableText(json['display_name']),
      avatarUrl: _nullableText(json['avatar_url']),
      primaryRole: primaryRole,
      primaryRoleBadge: primaryBadgeJson is Map<String, dynamic> ? RoleBadge.fromJson(primaryBadgeJson) : RoleBadge.fromRole(primaryRole),
      roleBadges: roleBadgesJson is List ? roleBadgesJson.whereType<Map<String, dynamic>>().map(RoleBadge.fromJson).toList(growable: false) : <RoleBadge>[RoleBadge.fromRole(primaryRole)],
      vip: UserVipSummary.fromJson(json['vip'] is Map<String, dynamic> ? json['vip'] as Map<String, dynamic> : null),
      isOnline: json['is_online'] == true,
      lastSeenAt: _date(json['last_seen_at']),
      createdAt: _date(json['created_at']) ?? DateTime.now(),
    );
  }

  String get visibleName => displayName ?? username ?? 'Vibe User';
  String get visibleId => displayCustomId?.toString() ?? publicUserId.toString();
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

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) return DateTime.tryParse(value);
  return null;
}
