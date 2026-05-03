import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../auth/data/auth_local_storage.dart';

class CreatedRoomResult {
  const CreatedRoomResult({
    required this.roomId,
    required this.name,
    required this.language,
    required this.mode,
    required this.type,
    required this.onlineCount,
    required this.coverImageUrl,
  });

  final String roomId;
  final String name;
  final String language;
  final String mode;
  final String type;
  final int onlineCount;
  final String? coverImageUrl;

  factory CreatedRoomResult.fromJson(Map<String, dynamic> json) {
    return CreatedRoomResult(
      roomId: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Live Room').toString(),
      language: (json['language'] ?? 'English').toString(),
      mode: (json['mode'] ?? 'Open').toString(),
      type: (json['type'] ?? 'Chat').toString(),
      onlineCount: _intFromJson(json['online_count'] ?? json['onlineCount']),
      coverImageUrl: _nullableString(json['cover_image_url'] ?? json['coverImageUrl']),
    );
  }

  static int _intFromJson(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}

class CreateRoomApiService {
  CreateRoomApiService({
    AuthLocalStorage? localStorage,
    http.Client? client,
  })  : _localStorage = localStorage ?? AuthLocalStorage(),
        _client = client ?? http.Client();

  final AuthLocalStorage _localStorage;
  final http.Client _client;

  Future<CreatedRoomResult> createRoom({
    required String name,
    required String language,
    required String mode,
    required String type,
    String? coverImageUrl,
  }) async {
    final token = await _localStorage.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Login required before creating a room.');
    }

    final uri = Uri.parse('${AppConstants.apiBaseUrl}/rooms');
    final response = await _client.post(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'name': name.trim(),
        'language': language.trim(),
        'mode': mode.trim(),
        'type': type.trim(),
        'cover_image_url': coverImageUrl,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Create room failed (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Create room failed: invalid backend response.');
    }

    return CreatedRoomResult.fromJson(decoded.cast<String, dynamic>());
  }
}
