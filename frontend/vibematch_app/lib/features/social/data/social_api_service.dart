import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

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
    final response = await _get('/social/friends');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final users = decoded['users'] as List<dynamic>? ?? const [];
    return users.whereType<Map<String, dynamic>>().map(PublicUserSummary.fromJson).toList();
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
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  void _throwIfFailed(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception('Social API failed (${response.statusCode}): ${response.body}');
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
}

int? publicUserIdFromRoomUserId(String userId) {
  final clean = userId.trim();
  if (clean.startsWith('user_')) return int.tryParse(clean.substring(5));
  return int.tryParse(clean);
}
