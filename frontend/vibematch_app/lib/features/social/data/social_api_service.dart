import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';
import '../models/social_user.dart';

class SocialApiService {
  const SocialApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<FollowStatus> getFollowStatusByPublicUserId(int publicUserId) async {
    final response = await _get('/social/public-users/$publicUserId/follow-status');
    return FollowStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<FollowStatus> followByPublicUserId(int publicUserId) async {
    final response = await _post('/social/public-users/$publicUserId/follow');
    return FollowStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<FollowStatus> unfollowByPublicUserId(int publicUserId) async {
    final response = await _delete('/social/public-users/$publicUserId/follow');
    return FollowStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<PublicUserSummary>> listFriends() async {
    final users = await listFriendUsers();
    return users.map(PublicUserSummary.fromSocialUser).toList(growable: false);
  }

  Future<List<SocialUser>> listFriendUsers({bool onlineOnly = false}) async {
    final response = await _get('/social/friends');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final users = decoded['users'] as List<dynamic>? ?? const [];
    final mapped = users
        .whereType<Map<String, dynamic>>()
        .map(SocialUser.fromJson)
        .where((user) => !onlineOnly || user.isOnline)
        .toList(growable: false);
    mapped.sort((a, b) {
      if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return mapped;
  }

  Future<void> sendRoomInvite({
    required int targetPublicUserId,
    required String roomName,
    String? roomPublicId,
    String? roomLanguage,
    String? modeTitle,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/conversations/direct/public/$targetPublicUserId/room-invite')),
      headers: _headers(),
      body: jsonEncode({
        'room_name': roomName,
        if (roomPublicId != null && roomPublicId.trim().isNotEmpty) 'room_public_id': roomPublicId.trim(),
        if (roomLanguage != null && roomLanguage.trim().isNotEmpty) 'room_language': roomLanguage.trim(),
        if (modeTitle != null && modeTitle.trim().isNotEmpty) 'mode_title': modeTitle.trim(),
      }),
    );
    _throwIfFailed(response);
  }

  Future<List<SocialUser>> listFollowingUsers() => _listSocialUsers('/social/following');

  Future<List<SocialUser>> listFollowerUsers() => _listSocialUsers('/social/followers');

  Future<List<SocialUser>> _listSocialUsers(String path) async {
    final response = await _get(path);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final users = decoded['users'] as List<dynamic>? ?? const [];
    return users.whereType<Map<String, dynamic>>().map(SocialUser.fromJson).toList(growable: false);
  }

  Future<http.Response> _get(String path) async {
    final response = await http.get(Uri.parse(VmApiConfig.endpoint(path)), headers: _headers());
    _throwIfFailed(response);
    return response;
  }

  Future<http.Response> _post(String path) async {
    final response = await http.post(Uri.parse(VmApiConfig.endpoint(path)), headers: _headers());
    _throwIfFailed(response);
    return response;
  }

  Future<http.Response> _delete(String path) async {
    final response = await http.delete(Uri.parse(VmApiConfig.endpoint(path)), headers: _headers());
    _throwIfFailed(response);
    return response;
  }

  Map<String, String> _headers() {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again.');
    }
    return {'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  void _throwIfFailed(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final body = response.body.trim();
    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          final detail = decoded['detail']?.toString().trim();
          if (detail != null && detail.isNotEmpty) throw Exception(detail);
        }
      } catch (_) {
        throw Exception(body);
      }
    }
    throw Exception('Social API failed (${response.statusCode})');
  }
}

class FollowStatus {
  const FollowStatus({
    required this.targetUser,
    required this.isFollowing,
    required this.isFollowedBy,
    required this.isFriends,
    required this.actionLabel,
  });

  final PublicUserSummary targetUser;
  final bool isFollowing;
  final bool isFollowedBy;
  final bool isFriends;
  final String actionLabel;

  factory FollowStatus.fromJson(Map<String, dynamic> json) {
    return FollowStatus(
      targetUser: PublicUserSummary.fromJson(json['target_user'] as Map<String, dynamic>? ?? const {}),
      isFollowing: json['is_following'] == true,
      isFollowedBy: json['is_followed_by'] == true,
      isFriends: json['is_friends'] == true,
      actionLabel: json['action_label']?.toString() ?? 'Follow',
    );
  }
}

class PublicUserSummary {
  const PublicUserSummary({
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

  String get title => displayName?.trim().isNotEmpty == true ? displayName! : (username ?? 'Vibe User');

  factory PublicUserSummary.fromJson(Map<String, dynamic> json) {
    return PublicUserSummary(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      publicUserId: int.tryParse(json['public_user_id']?.toString() ?? '') ?? 0,
      username: json['username']?.toString(),
      displayName: json['display_name']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
    );
  }

  factory PublicUserSummary.fromSocialUser(SocialUser user) {
    return PublicUserSummary(
      id: int.tryParse(user.id) ?? 0,
      publicUserId: user.publicUserId ?? int.tryParse(user.id) ?? 0,
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
    );
  }
}

int? publicUserIdFromRoomUserId(String userId) {
  final clean = userId.trim();
  if (clean.startsWith('user_')) return int.tryParse(clean.substring(5));
  return int.tryParse(clean);
}
