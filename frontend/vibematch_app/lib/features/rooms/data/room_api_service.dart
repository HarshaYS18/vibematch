import 'dart:convert';

import 'package:http/http.dart' as http;

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
  }) async {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before creating a room.');
    }

    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/rooms')),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name.trim(),
        'subtitle': subtitle?.trim(),
        'language': language.trim(),
        'mode': mode.trim(),
        'type': type.trim(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to create room (${response.statusCode}): ${response.body}');
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

  Future<RealRoom> getRoom(String roomId) async {
    final response = await http.get(Uri.parse(VmApiConfig.endpoint('/rooms/$roomId')));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load room (${response.statusCode}): ${response.body}');
    }
    return RealRoom.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
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
    this.ownerUserId,
    this.isActive = true,
    this.isSecret = false,
    this.isLocked = false,
    this.isMembersOnly = false,
  });

  final String id;
  final String name;
  final String? subtitle;
  final String language;
  final String mode;
  final String type;
  final int onlineCount;
  final int trendingScore;
  final int? ownerUserId;
  final bool isActive;
  final bool isSecret;
  final bool isLocked;
  final bool isMembersOnly;

  factory RealRoom.fromJson(Map<String, dynamic> json) {
    return RealRoom(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Live Room',
      subtitle: json['subtitle']?.toString(),
      language: json['language']?.toString() ?? 'English',
      mode: json['mode']?.toString() ?? 'Open',
      type: json['type']?.toString() ?? 'Chat',
      onlineCount: int.tryParse(json['online_count']?.toString() ?? '') ?? 0,
      trendingScore: int.tryParse(json['trending_score']?.toString() ?? '') ?? 0,
      ownerUserId: int.tryParse(json['owner_user_id']?.toString() ?? ''),
      isActive: json['is_active'] != false,
      isSecret: json['is_secret'] == true,
      isLocked: json['is_locked'] == true,
      isMembersOnly: json['is_members_only'] == true,
    );
  }
}
