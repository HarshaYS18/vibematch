import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class LuckyPacketApiService {
  const LuckyPacketApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<LuckyPacketApiResult> create({
    required String roomPublicId,
    required int coinAmount,
    required int winnerCount,
    required String message,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/economy/lucky-packets')),
      headers: _headers(),
      body: jsonEncode({
        'room_public_id': roomPublicId,
        'coin_amount': coinAmount,
        'winner_count': winnerCount,
        'message': message.trim(),
      }),
    );
    _throwIfBad(response, 'Lucky Packet send failed');
    return _parse(response.body);
  }

  Future<LuckyPacketApiResult?> fetchActive({required String roomPublicId}) async {
    final uri = Uri.parse(
      VmApiConfig.endpoint('/economy/lucky-packets/active'),
    ).replace(queryParameters: {'room_public_id': roomPublicId});
    final response = await http.get(uri, headers: _headers());
    _throwIfBad(response, 'Lucky Packet refresh failed');
    final decoded = jsonDecode(response.body);
    if (decoded == null) return null;
    return LuckyPacketApiResult.fromJson((decoded as Map).cast<String, dynamic>());
  }

  Future<LuckyPacketApiResult> fetchPacket(String packetId) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/economy/lucky-packets/$packetId')),
      headers: _headers(),
    );
    _throwIfBad(response, 'Lucky Packet refresh failed');
    return _parse(response.body);
  }

  Future<LuckyPacketApiResult> claim(String packetId) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/economy/lucky-packets/$packetId/claim')),
      headers: _headers(),
    );
    _throwIfBad(response, 'Lucky Packet claim failed');
    return _parse(response.body);
  }

  Future<LuckyPacketApiResult> finalize(String packetId) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/economy/lucky-packets/$packetId/finalize')),
      headers: _headers(),
    );
    _throwIfBad(response, 'Lucky Packet finalize failed');
    return _parse(response.body);
  }

  LuckyPacketApiResult _parse(String body) => LuckyPacketApiResult.fromJson(
    (jsonDecode(body) as Map).cast<String, dynamic>(),
  );

  Map<String, String> _headers() {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('No access token available. Please login again.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _throwIfBad(http.Response response, String label) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$label (${response.statusCode}): ${response.body}');
    }
  }
}

class LuckyPacketApiResult {
  const LuckyPacketApiResult({
    required this.packetId,
    required this.roomPublicId,
    required this.senderUserId,
    required this.senderName,
    required this.coinAmount,
    required this.winnerCount,
    required this.message,
    required this.phase,
    required this.remainingSeconds,
    required this.claims,
    required this.claimedCount,
    required this.claimedCoinAmount,
    required this.refundedCoinAmount,
    required this.createdAt,
    this.currentUserReward,
    this.senderCoinBalance,
    this.walletCoinBalance,
  });

  final String packetId;
  final String roomPublicId;
  final String senderUserId;
  final String senderName;
  final int coinAmount;
  final int winnerCount;
  final String message;
  final String phase;
  final int remainingSeconds;
  final Map<String, int> claims;
  final int claimedCount;
  final int claimedCoinAmount;
  final int refundedCoinAmount;
  final DateTime createdAt;
  final int? currentUserReward;
  final int? senderCoinBalance;
  final int? walletCoinBalance;

  factory LuckyPacketApiResult.fromJson(Map<String, dynamic> json) {
    final claims = <String, int>{};
    final rawClaims = json['claims'];
    if (rawClaims is Map) {
      for (final entry in rawClaims.entries) {
        claims[entry.key.toString()] = _int(entry.value);
      }
    }
    return LuckyPacketApiResult(
      packetId: json['packet_id']?.toString() ?? '',
      roomPublicId: json['room_public_id']?.toString() ?? '',
      senderUserId: json['sender_user_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? 'Vibe User',
      coinAmount: _int(json['coin_amount']),
      winnerCount: _int(json['winner_count']),
      message: json['message']?.toString() ?? '',
      phase: json['phase']?.toString() ?? 'countdown',
      remainingSeconds: _int(json['remaining_seconds']),
      claims: claims,
      claimedCount: _int(json['claimed_count']),
      claimedCoinAmount: _int(json['claimed_coin_amount']),
      refundedCoinAmount: _int(json['refunded_coin_amount']),
      currentUserReward: json['current_user_reward'] == null
          ? null
          : _int(json['current_user_reward']),
      senderCoinBalance: json['sender_coin_balance'] == null
          ? null
          : _int(json['sender_coin_balance']),
      walletCoinBalance: json['wallet_coin_balance'] == null
          ? null
          : _int(json['wallet_coin_balance']),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
