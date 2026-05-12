import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class LoveBondApiService {
  const LoveBondApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<List<LoveBondInventoryItemDto>> getInventory() async {
    final response = await _get('/love-bonds/inventory');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(LoveBondInventoryItemDto.fromJson)
        .toList(growable: false);
  }

  Future<LoveBondRequestDto> sendRequest({
    required int receiverPublicUserId,
    required String cardType,
  }) async {
    final response = await _post(
      '/love-bonds/requests',
      body: {
        'receiver_public_user_id': receiverPublicUserId,
        'card_type': cardType,
      },
    );
    return LoveBondRequestDto.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<LoveBondRequestDto>> listPendingRequests() async {
    final response = await _get('/love-bonds/requests/pending');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final requests = decoded['requests'] as List<dynamic>? ?? const [];
    return requests
        .whereType<Map<String, dynamic>>()
        .map(LoveBondRequestDto.fromJson)
        .toList(growable: false);
  }

  Future<LoveBondDto> acceptRequest(String requestId) async {
    final response = await _post('/love-bonds/requests/$requestId/accept');
    return LoveBondDto.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<LoveBondRequestDto> rejectRequest(String requestId) async {
    final response = await _post('/love-bonds/requests/$requestId/reject');
    return LoveBondRequestDto.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<LoveBondDto>> listMyBonds() async {
    final response = await _get('/love-bonds/me');
    return _decodeBondList(response.body);
  }

  Future<List<LoveBondDto>> listPublicBonds(int publicUserId) async {
    final response = await _get('/love-bonds/public/$publicUserId');
    return _decodeBondList(response.body);
  }

  List<LoveBondDto> _decodeBondList(String body) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final bonds = decoded['bonds'] as List<dynamic>? ?? const [];
    return bonds.whereType<Map<String, dynamic>>().map(LoveBondDto.fromJson).toList(growable: false);
  }

  Future<http.Response> _get(String path) async {
    final response = await http.get(Uri.parse(VmApiConfig.endpoint(path)), headers: _headers());
    _throwIfFailed(response);
    return response;
  }

  Future<http.Response> _post(String path, {Map<String, dynamic>? body}) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint(path)),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    _throwIfFailed(response);
    return response;
  }

  Map<String, String> _headers() {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again.');
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _throwIfFailed(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final body = response.body.trim();
    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          final detail = decoded['detail'];
          if (detail is String && detail.trim().isNotEmpty) throw Exception(detail);
          if (detail is List && detail.isNotEmpty) throw Exception(detail.first.toString());
        }
      } catch (_) {
        throw Exception(body);
      }
    }

    throw Exception('Love Bonds API failed (${response.statusCode})');
  }
}

class LoveBondInventoryItemDto {
  const LoveBondInventoryItemDto({
    required this.cardType,
    required this.cardName,
    required this.quantity,
    required this.reservedQuantity,
    required this.availableQuantity,
    this.source,
  });

  final String cardType;
  final String cardName;
  final int quantity;
  final int reservedQuantity;
  final int availableQuantity;
  final String? source;

  factory LoveBondInventoryItemDto.fromJson(Map<String, dynamic> json) {
    return LoveBondInventoryItemDto(
      cardType: json['card_type']?.toString() ?? '',
      cardName: json['card_name']?.toString() ?? '',
      quantity: _readInt(json['quantity']),
      reservedQuantity: _readInt(json['reserved_quantity']),
      availableQuantity: _readInt(json['available_quantity']),
      source: json['source']?.toString(),
    );
  }
}

class LoveBondRequestDto {
  const LoveBondRequestDto({
    required this.id,
    required this.senderPublicUserId,
    required this.senderName,
    required this.receiverPublicUserId,
    required this.receiverName,
    required this.cardType,
    required this.cardName,
    required this.status,
    this.createdAt,
    this.respondedAt,
  });

  final String id;
  final int senderPublicUserId;
  final String senderName;
  final int receiverPublicUserId;
  final String receiverName;
  final String cardType;
  final String cardName;
  final String status;
  final String? createdAt;
  final String? respondedAt;

  factory LoveBondRequestDto.fromJson(Map<String, dynamic> json) {
    return LoveBondRequestDto(
      id: json['id']?.toString() ?? '',
      senderPublicUserId: _readInt(json['sender_public_user_id']),
      senderName: json['sender_name']?.toString() ?? 'Vibe User',
      receiverPublicUserId: _readInt(json['receiver_public_user_id']),
      receiverName: json['receiver_name']?.toString() ?? 'Vibe User',
      cardType: json['card_type']?.toString() ?? '',
      cardName: json['card_name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['created_at']?.toString(),
      respondedAt: json['responded_at']?.toString(),
    );
  }
}

class LoveBondDto {
  const LoveBondDto({
    required this.id,
    required this.cardType,
    required this.status,
    required this.loveScore,
    required this.level,
    required this.partnerPublicUserId,
    required this.partnerName,
    this.partnerAvatarUrl,
    this.partnerGender,
    this.startedAt,
  });

  final String id;
  final String cardType;
  final String status;
  final int loveScore;
  final int level;
  final int partnerPublicUserId;
  final String partnerName;
  final String? partnerAvatarUrl;
  final String? partnerGender;
  final String? startedAt;

  factory LoveBondDto.fromJson(Map<String, dynamic> json) {
    return LoveBondDto(
      id: json['id']?.toString() ?? '',
      cardType: json['card_type']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      loveScore: _readInt(json['love_score']),
      level: _readInt(json['level'], fallback: 1),
      partnerPublicUserId: _readInt(json['partner_public_user_id']),
      partnerName: json['partner_name']?.toString() ?? 'Vibe User',
      partnerAvatarUrl: json['partner_avatar_url']?.toString(),
      partnerGender: json['partner_gender']?.toString(),
      startedAt: json['started_at']?.toString(),
    );
  }
}

int _readInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
