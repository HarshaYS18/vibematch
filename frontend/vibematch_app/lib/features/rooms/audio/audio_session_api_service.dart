import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../auth/data/auth_local_storage.dart';

class AudioSessionApiService {
  AudioSessionApiService({
    AuthLocalStorage? storage,
    http.Client? client,
  })  : _storage = storage ?? AuthLocalStorage(),
        _client = client ?? http.Client();

  final AuthLocalStorage _storage;
  final http.Client _client;

  Future<AudioSessionResponse> createRoomAudioSession(String roomId) async {
    final token = await _storage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('Missing auth token. Login before joining room audio.');
    }

    final uri = Uri.parse('${AppConstants.apiBaseUrl}/audio/rooms/$roomId/session');
    final response = await _client
        .post(
          uri,
          headers: <String, String>{
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        )
        .timeout(AppConstants.receiveTimeout);

    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? decoded['detail'] : null;
      throw Exception('Audio session failed: ${detail ?? response.body}');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid audio session response');
    }

    return AudioSessionResponse.fromJson(decoded);
  }
}

class AudioSessionResponse {
  const AudioSessionResponse({
    required this.audioToken,
    required this.roomId,
    required this.peerId,
    required this.engine,
    required this.expiresAt,
  });

  final String audioToken;
  final String roomId;
  final String peerId;
  final String engine;
  final String expiresAt;

  factory AudioSessionResponse.fromJson(Map<String, dynamic> json) {
    return AudioSessionResponse(
      audioToken: json['audio_token']?.toString() ?? '',
      roomId: json['room_id']?.toString() ?? '',
      peerId: json['peer_id']?.toString() ?? '',
      engine: json['engine']?.toString() ?? 'mediasoup',
      expiresAt: json['expires_at']?.toString() ?? '',
    );
  }
}
