import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class InboxStoryItem {
  const InboxStoryItem({
    required this.id,
    required this.ownerUserId,
    required this.ownerName,
    required this.mediaUrl,
    required this.mediaType,
    required this.visibility,
    required this.viewCount,
    required this.isMine,
    required this.isViewed,
    this.ownerAvatarUrl,
    this.caption,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final int ownerUserId;
  final String ownerName;
  final String? ownerAvatarUrl;
  final String mediaUrl;
  final String mediaType;
  final String? caption;
  final String visibility;
  final int viewCount;
  final bool isMine;
  final bool isViewed;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  static InboxStoryItem fromJson(Map<String, dynamic> json) {
    return InboxStoryItem(
      id: json['id']?.toString() ?? '',
      ownerUserId: (json['owner_user_id'] as num?)?.toInt() ?? 0,
      ownerName: json['owner_name']?.toString() ?? 'Story',
      ownerAvatarUrl: _nullable(json['owner_avatar_url']),
      mediaUrl: json['media_url']?.toString() ?? '',
      mediaType: json['media_type']?.toString() ?? 'image',
      caption: _nullable(json['caption']),
      visibility: json['visibility']?.toString() ?? 'friends',
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      isMine: json['is_mine'] == true,
      isViewed: json['is_viewed'] == true,
      createdAt: _date(json['created_at']),
      expiresAt: _date(json['expires_at']),
    );
  }

  static String? _nullable(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static DateTime? _date(Object? value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }
}

class InboxStoriesApiService {
  const InboxStoriesApiService({AuthApiService authApiService = const AuthApiService()}) : _authApiService = authApiService;

  final AuthApiService _authApiService;

  Future<Map<String, String>> _headers() async {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('No auth token available for Inbox stories. Login first.');
    }
    return <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Future<List<InboxStoryItem>> loadStories() async {
    final response = await http.get(Uri.parse(VmApiConfig.endpoint('/inbox/stories')), headers: await _headers());
    _throwIfFailed(response, 'load stories');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['stories'] as List<dynamic>? ?? const [];
    return items.whereType<Map<String, dynamic>>().map(InboxStoryItem.fromJson).where((item) => item.id.isNotEmpty && item.mediaUrl.isNotEmpty).toList();
  }

  Future<InboxStoryItem> createStory({required String mediaUrl, required String mediaType, String? caption, String visibility = 'friends'}) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/stories')),
      headers: await _headers(),
      body: jsonEncode(<String, Object?>{
        'media_url': mediaUrl,
        'media_type': mediaType,
        'caption': caption,
        'visibility': visibility,
      }),
    );
    _throwIfFailed(response, 'create story');
    return InboxStoryItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<InboxStoryItem> markViewed(String storyId) async {
    final response = await http.post(Uri.parse(VmApiConfig.endpoint('/inbox/stories/$storyId/view')), headers: await _headers());
    _throwIfFailed(response, 'mark story viewed');
    return InboxStoryItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteStory(String storyId) async {
    final response = await http.delete(Uri.parse(VmApiConfig.endpoint('/inbox/stories/$storyId')), headers: await _headers());
    _throwIfFailed(response, 'delete story');
  }

  void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception('Inbox stories failed to $action (${response.statusCode}): ${response.body}');
  }
}
