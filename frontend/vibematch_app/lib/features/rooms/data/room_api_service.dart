import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class RoomApiService {
  const RoomApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<RealRoom> createRoom({
    required String name,
    required String language,
    required String mode,
    String type = 'Chat',
    String? subtitle,
    String? avatarUrl,
    String? coverPhotoUrl,
    String? lockPassword,
    bool? allowScreenshots,
  }) async {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before creating a room.');
    }

    final body = <String, dynamic>{
      'name': name.trim(),
      'subtitle': subtitle?.trim(),
      'avatar_url': avatarUrl?.trim(),
      'cover_photo_url': coverPhotoUrl?.trim() ?? avatarUrl?.trim(),
      'language': language.trim(),
      'mode': mode.trim(),
      'type': type.trim(),
      if (lockPassword != null && lockPassword.trim().isNotEmpty) 'lock_password': lockPassword.trim(),
      'allow_screenshots': ?allowScreenshots,
    };

    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/rooms')),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, fallback: 'Failed to create room'));
    }

    return RealRoom.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<RealRoom> updateRoomMode({required String roomId, required String mode, String? lockPassword}) async {
    final response = await http.patch(
      Uri.parse(VmApiConfig.endpoint('/rooms/$roomId/mode')),
      headers: _authHeaders(),
      body: jsonEncode({
        'mode': mode.trim(),
        if (lockPassword != null && lockPassword.trim().isNotEmpty) 'lock_password': lockPassword.trim(),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, fallback: 'Failed to update room mode'));
    }
    return RealRoom.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<RealRoom>> listTrendingRooms({String? language, String? category, int limit = 30}) async {
    final query = <String, String>{'limit': '$limit'};
    if (language != null && language.trim().isNotEmpty) query['language'] = language.trim();
    if (category != null && category.trim().isNotEmpty) query['category'] = category.trim();

    final uri = Uri.parse(VmApiConfig.endpoint('/rooms/trending')).replace(queryParameters: query);
    final response = await http.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load rooms (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.whereType<Map<String, dynamic>>().map(RealRoom.fromJson).toList();
  }

  Future<List<RealRoom>> listFollowingRooms({String? language, String? category, int limit = 30}) async {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before loading following rooms.');
    }

    final query = <String, String>{'limit': '$limit'};
    if (language != null && language.trim().isNotEmpty) query['language'] = language.trim();
    if (category != null && category.trim().isNotEmpty) query['category'] = category.trim();

    final uri = Uri.parse(VmApiConfig.endpoint('/rooms/following')).replace(queryParameters: query);
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load following rooms (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.whereType<Map<String, dynamic>>().map(RealRoom.fromJson).toList();
  }

  Future<RealRoom> getRoom(String roomId) async {
    final response = await http.get(Uri.parse(VmApiConfig.endpoint('/rooms/$roomId')));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load room (${response.statusCode}): ${response.body}');
    }
    return RealRoom.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<RoomJoinSnapshot> joinRoom(String roomId, {String? lockPassword}) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/rooms/$roomId/join')),
      headers: _authHeaders(),
      body: jsonEncode({
        if (lockPassword != null && lockPassword.trim().isNotEmpty) 'lock_password': lockPassword.trim(),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, fallback: 'Failed to join room'));
    }
    return RoomJoinSnapshot.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<RoomJoinSnapshot> heartbeatRoom(String roomId) async {
    final response = await http.post(Uri.parse(VmApiConfig.endpoint('/rooms/$roomId/heartbeat')), headers: _authHeaders());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to heartbeat room (${response.statusCode}): ${response.body}');
    }
    return RoomJoinSnapshot.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> leaveRoom(String roomId) async {
    final response = await http.post(Uri.parse(VmApiConfig.endpoint('/rooms/$roomId/leave')), headers: _authHeaders());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to leave room (${response.statusCode}): ${response.body}');
    }
  }

  Future<List<RoomParticipantDto>> listParticipants(String roomId) async {
    final response = await http.get(Uri.parse(VmApiConfig.endpoint('/rooms/$roomId/participants')), headers: _authHeaders());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load participants (${response.statusCode}): ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['participants'] as List<dynamic>? ?? const [];
    return items.whereType<Map<String, dynamic>>().map(RoomParticipantDto.fromJson).toList(growable: false);
  }

  Future<MediaUploadResult> uploadRoomCover(XFile file) {
    return _uploadMedia('/media/room-cover', file);
  }

  Future<MediaUploadResult> uploadRoomBackground(XFile file) {
    return _uploadMedia('/media/room-background', file);
  }

  Future<MediaUploadResult> _uploadMedia(String path, XFile file) async {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) throw Exception('Please login again.');
    final request = http.MultipartRequest('POST', Uri.parse(VmApiConfig.endpoint(path)));
    request.headers['Authorization'] = 'Bearer $token';
    final bytes = await file.readAsBytes();
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: file.name));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, fallback: 'Upload failed'));
    }
    return MediaUploadResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<RoomSettingsDto> updateRoomCoverPhoto({required String roomId, required String coverPhotoUrl}) async {
    final response = await http.patch(
      Uri.parse(VmApiConfig.endpoint('/rooms/$roomId/cover-photo')),
      headers: _authHeaders(),
      body: jsonEncode({'cover_photo_url': coverPhotoUrl.trim()}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, fallback: 'Failed to update cover photo'));
    }
    return RoomSettingsDto.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<RoomThemeDto>> listRoomThemes() async {
    final response = await http.get(Uri.parse(VmApiConfig.endpoint('/rooms/themes')), headers: _authHeaders());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, fallback: 'Failed to load room backgrounds'));
    }
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.whereType<Map<String, dynamic>>().map(RoomThemeDto.fromJson).toList(growable: false);
  }

  Future<RoomThemeDto> purchaseRoomTheme(String themeId) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/rooms/themes/purchase')),
      headers: _authHeaders(),
      body: jsonEncode({'theme_id': themeId}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, fallback: 'Failed to purchase background'));
    }
    return RoomThemeDto.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<RoomSettingsDto> applyRoomTheme({required String roomId, required String themeId}) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/rooms/$roomId/background-theme')),
      headers: _authHeaders(),
      body: jsonEncode({'theme_id': themeId}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, fallback: 'Failed to apply background'));
    }
    return RoomSettingsDto.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<CustomBackgroundReviewDto> submitCustomBackground({required String roomId, required String imageUrl, String? thumbnailUrl}) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/rooms/custom-backgrounds')),
      headers: _authHeaders(),
      body: jsonEncode({
        'room_public_id': roomId,
        'image_url': imageUrl.trim(),
        if (thumbnailUrl != null && thumbnailUrl.trim().isNotEmpty) 'thumbnail_url': thumbnailUrl.trim(),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, fallback: 'Failed to submit custom background'));
    }
    return CustomBackgroundReviewDto.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Map<String, String> _authHeaders() {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  String _errorMessage(http.Response response, {required String fallback}) {
    final body = response.body.trim();
    if (body.isEmpty) return '$fallback (${response.statusCode})';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) return detail.trim();
        if (detail != null) return detail.toString();
      }
    } catch (_) {
      return body;
    }
    return '$fallback (${response.statusCode})';
  }
}

class RealRoom {
  const RealRoom({
    required this.id,
    required this.name,
    required this.language,
    required this.mode,
    required this.type,
    required this.onlineCount,
    required this.trendingScore,
    this.subtitle,
    this.avatarUrl,
    this.coverPhotoUrl,
    this.followedFriendsInside = const <String>[],
    this.ownerUserId,
    this.isActive = true,
    this.isSecret = false,
    this.isLocked = false,
    this.isMembersOnly = false,
    this.allowScreenshots = true,
    this.hasLockPassword = false,
  });

  final String id;
  final String name;
  final String? subtitle;
  final String? avatarUrl;
  final String? coverPhotoUrl;
  final String language;
  final String mode;
  final String type;
  final int onlineCount;
  final int trendingScore;
  final List<String> followedFriendsInside;
  final int? ownerUserId;
  final bool isActive;
  final bool isSecret;
  final bool isLocked;
  final bool isMembersOnly;
  final bool allowScreenshots;
  final bool hasLockPassword;

  factory RealRoom.fromJson(Map<String, dynamic> json) {
    final friends = json['followed_friends_inside'];
    return RealRoom(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Live Room',
      subtitle: json['subtitle']?.toString(),
      avatarUrl: _nullableString(json['avatar_url']),
      coverPhotoUrl: _nullableString(json['cover_photo_url'] ?? json['coverPhotoUrl'] ?? json['avatar_url']),
      language: json['language']?.toString() ?? 'English',
      mode: json['mode']?.toString() ?? 'Open',
      type: json['type']?.toString() ?? 'Chat',
      onlineCount: int.tryParse(json['online_count']?.toString() ?? '') ?? 0,
      trendingScore: int.tryParse(json['trending_score']?.toString() ?? '') ?? 0,
      followedFriendsInside: friends is List ? friends.map((item) => item.toString()).toList(growable: false) : const <String>[],
      ownerUserId: int.tryParse(json['owner_user_id']?.toString() ?? ''),
      isActive: json['is_active'] != false,
      isSecret: json['is_secret'] == true,
      isLocked: json['is_locked'] == true,
      isMembersOnly: json['is_members_only'] == true,
      allowScreenshots: json['allow_screenshots'] != false,
      hasLockPassword: json['has_lock_password'] == true,
    );
  }
}

class RoomJoinSnapshot {
  const RoomJoinSnapshot({required this.room, required this.participants, this.shouldShowEnteredMessage = false});

  final RealRoom room;
  final List<RoomParticipantDto> participants;
  final bool shouldShowEnteredMessage;

  factory RoomJoinSnapshot.fromJson(Map<String, dynamic> json) {
    final participants = json['participants'] as List<dynamic>? ?? const [];
    return RoomJoinSnapshot(
      room: RealRoom.fromJson((json['room'] as Map<String, dynamic>?) ?? const <String, dynamic>{}),
      participants: participants.whereType<Map<String, dynamic>>().map(RoomParticipantDto.fromJson).toList(growable: false),
      shouldShowEnteredMessage: json['should_show_entered_message'] == true,
    );
  }
}

class RoomParticipantDto {
  const RoomParticipantDto({
    required this.publicUserId,
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.primaryRole,
    required this.isOwner,
    required this.isMember,
    required this.isRoomAdmin,
    this.equippedAvatarFrameAssetPath,
    this.equippedAvatarFrameImageUrl,
    this.equippedChatBubbleAssetPath,
    this.equippedChatBubbleImageUrl,
  });

  final int publicUserId;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final String primaryRole;
  final bool isOwner;
  final bool isMember;
  final bool isRoomAdmin;
  final String? equippedAvatarFrameAssetPath;
  final String? equippedAvatarFrameImageUrl;
  final String? equippedChatBubbleAssetPath;
  final String? equippedChatBubbleImageUrl;

  factory RoomParticipantDto.fromJson(Map<String, dynamic> json) {
    final publicId = int.tryParse(json['public_user_id']?.toString() ?? '') ?? 0;
    final username = _nullableString(json['username']) ?? 'user_$publicId';
    final equipped = json['equipped_items'];
    final equippedMap = equipped is Map<String, dynamic> ? equipped : const <String, dynamic>{};
    final avatarFrame = equippedMap['avatar_frame'];
    final avatarFrameMap = avatarFrame is Map<String, dynamic> ? avatarFrame : const <String, dynamic>{};
    final chatBubble = equippedMap['chat_bubble'];
    final chatBubbleMap = chatBubble is Map<String, dynamic> ? chatBubble : const <String, dynamic>{};
    return RoomParticipantDto(
      publicUserId: publicId,
      displayName: _nullableString(json['display_name']) ?? username,
      username: username,
      avatarUrl: _nullableString(json['avatar_url']),
      primaryRole: json['primary_role']?.toString() ?? 'user',
      isOwner: json['is_owner'] == true,
      isMember: json['is_member'] == true,
      isRoomAdmin: json['is_room_admin'] == true,
      equippedAvatarFrameAssetPath: _nullableString(avatarFrameMap['asset_path']),
      equippedAvatarFrameImageUrl: _nullableString(avatarFrameMap['image_url']),
      equippedChatBubbleAssetPath: _nullableString(chatBubbleMap['asset_path']),
      equippedChatBubbleImageUrl: _nullableString(chatBubbleMap['image_url']),
    );
  }
}

class MediaUploadResult {
  const MediaUploadResult({required this.url, required this.mediaType, required this.contentType, required this.sizeBytes});

  final String url;
  final String mediaType;
  final String contentType;
  final int sizeBytes;

  factory MediaUploadResult.fromJson(Map<String, dynamic> json) {
    return MediaUploadResult(
      url: json['url']?.toString() ?? '',
      mediaType: json['media_type']?.toString() ?? 'image',
      contentType: json['content_type']?.toString() ?? '',
      sizeBytes: int.tryParse(json['size_bytes']?.toString() ?? '') ?? 0,
    );
  }
}

class RoomSettingsDto {
  const RoomSettingsDto({required this.roomPublicId, this.coverPhotoUrl, this.backgroundThemeId = 'default'});

  final String roomPublicId;
  final String? coverPhotoUrl;
  final String backgroundThemeId;

  factory RoomSettingsDto.fromJson(Map<String, dynamic> json) {
    return RoomSettingsDto(
      roomPublicId: json['room_public_id']?.toString() ?? '',
      coverPhotoUrl: _nullableString(json['cover_photo_url']),
      backgroundThemeId: json['background_theme_id']?.toString() ?? 'default',
    );
  }
}

class RoomThemeDto {
  const RoomThemeDto({required this.themeId, required this.name, required this.ownershipType, required this.priceCoins, required this.isOwned, required this.isDefault, this.imageUrl, this.assetPath});

  final String themeId;
  final String name;
  final String ownershipType;
  final int priceCoins;
  final bool isOwned;
  final bool isDefault;
  final String? imageUrl;
  final String? assetPath;

  bool get isFree => ownershipType == 'free' || priceCoins <= 0;

  factory RoomThemeDto.fromJson(Map<String, dynamic> json) {
    return RoomThemeDto(
      themeId: json['theme_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Room Background',
      ownershipType: json['ownership_type']?.toString() ?? 'free',
      priceCoins: int.tryParse(json['price_coins']?.toString() ?? '') ?? 0,
      isOwned: json['is_owned'] == true,
      isDefault: json['is_default'] == true,
      imageUrl: _nullableString(json['image_url']),
      assetPath: _nullableString(json['asset_path']),
    );
  }
}

class CustomBackgroundReviewDto {
  const CustomBackgroundReviewDto({required this.reviewPublicId, required this.status, required this.proposedThemeId});

  final String reviewPublicId;
  final String status;
  final String proposedThemeId;

  factory CustomBackgroundReviewDto.fromJson(Map<String, dynamic> json) {
    return CustomBackgroundReviewDto(
      reviewPublicId: json['review_public_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      proposedThemeId: json['proposed_theme_id']?.toString() ?? '',
    );
  }
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}
