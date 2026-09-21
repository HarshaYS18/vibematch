import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class GiftApiService {
  const GiftApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<LuckyGiftRollResult> rollLuckyGift({
    required String giftId,
    required int quantity,
    int houseRiskScore = 0,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/gifts/lucky/roll')),
      headers: _headers(),
      body: jsonEncode({
        'gift_id': giftId,
        'quantity': quantity,
        'house_risk_score': houseRiskScore,
      }),
    );
    _throwIfBad(response, 'Lucky gift roll failed');
    return LuckyGiftRollResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<GiftSendPublicResult> sendGiftPublic({
    required int receiverPublicUserId,
    required String giftId,
    required int coinValue,
    required int quantity,
    String? roomPublicId,
    int? relationshipId,
    bool isRelationshipGift = false,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/economy/gifts/send')),
      headers: _headers(),
      body: jsonEncode({
        'receiver_public_user_id': receiverPublicUserId,
        'gift_id': giftId,
        'quantity': quantity,
        'room_public_id': roomPublicId,
        'relationship_id': relationshipId,
        'is_relationship_gift': isRelationshipGift,
      }),
    );
    _throwIfBad(response, 'Gift send failed');
    return GiftSendPublicResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<GiftSendPublicResult> sendLuckyGiftPublic({
    required int receiverPublicUserId,
    required String giftId,
    required int coinValue,
    required int quantity,
    String? roomPublicId,
    int houseRiskScore = 0,
    int? relationshipId,
    bool isRelationshipGift = false,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/economy/gifts/send')),
      headers: _headers(),
      body: jsonEncode({
        'receiver_public_user_id': receiverPublicUserId,
        'gift_id': giftId,
        'quantity': quantity,
        'room_public_id': roomPublicId,
        'house_risk_score': houseRiskScore,
        'relationship_id': relationshipId,
        'is_relationship_gift': isRelationshipGift,
      }),
    );
    _throwIfBad(response, 'Lucky gift send failed');
    return GiftSendPublicResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Map<String, String> _headers() {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('No access token available. Please login again.');
    }
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  void _throwIfBad(http.Response response, String label) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$label (${response.statusCode}): ${response.body}');
    }
  }
}

class LuckyGiftRollResult {
  const LuckyGiftRollResult({
    required this.giftId,
    required this.giftName,
    required this.baseCoinValue,
    required this.totalCoinValue,
    required this.multiplier,
    required this.rewardCoinAmount,
    required this.riskLabel,
    required this.isGlobalBroadcastWorthy,
  });

  final String giftId;
  final String giftName;
  final int baseCoinValue;
  final int totalCoinValue;
  final int multiplier;
  final int rewardCoinAmount;
  final String riskLabel;
  final bool isGlobalBroadcastWorthy;

  factory LuckyGiftRollResult.fromJson(Map<String, dynamic> json) => LuckyGiftRollResult(
        giftId: json['gift_id']?.toString() ?? '',
        giftName: json['gift_name']?.toString() ?? '',
        baseCoinValue: _int(json['base_coin_value']),
        totalCoinValue: _int(json['total_coin_value']),
        multiplier: _int(json['multiplier']),
        rewardCoinAmount: _int(json['reward_coin_amount']),
        riskLabel: json['risk_label']?.toString() ?? '',
        isGlobalBroadcastWorthy: json['is_global_broadcast_worthy'] == true,
      );
}

class GiftSendPublicResult {
  const GiftSendPublicResult({
    required this.giftTransactionId,
    required this.senderUserId,
    required this.receiverUserId,
    required this.totalCoinValue,
    required this.receiverRubyAmount,
    required this.senderCoinBalance,
    required this.receiverRubyBalance,
    this.luckyMultiplier,
    this.luckyRewardCoinAmount,
    this.luckyResult,
  });

  final int giftTransactionId;
  final int senderUserId;
  final int receiverUserId;
  final int totalCoinValue;
  final int receiverRubyAmount;
  final int senderCoinBalance;
  final int receiverRubyBalance;
  final int? luckyMultiplier;
  final int? luckyRewardCoinAmount;
  final LuckyGiftRollResult? luckyResult;

  factory GiftSendPublicResult.fromJson(Map<String, dynamic> json) {
    final rawLuckyResult = json['lucky_result'];
    final parsedLuckyResult = rawLuckyResult is Map<String, dynamic>
        ? LuckyGiftRollResult.fromJson(rawLuckyResult)
        : rawLuckyResult is Map
            ? LuckyGiftRollResult.fromJson(rawLuckyResult.cast<String, dynamic>())
            : null;
    return GiftSendPublicResult(
      giftTransactionId: _int(json['gift_transaction_id']),
      senderUserId: _int(json['sender_user_id']),
      receiverUserId: _int(json['receiver_user_id']),
      totalCoinValue: _int(json['total_coin_value']),
      receiverRubyAmount: _int(json['receiver_ruby_amount']),
      senderCoinBalance: _int(json['sender_coin_balance']),
      receiverRubyBalance: _int(json['receiver_ruby_balance']),
      luckyMultiplier: json.containsKey('lucky_multiplier') ? _int(json['lucky_multiplier']) : parsedLuckyResult?.multiplier,
      luckyRewardCoinAmount: json.containsKey('lucky_reward_coin_amount') ? _int(json['lucky_reward_coin_amount']) : parsedLuckyResult?.rewardCoinAmount,
      luckyResult: parsedLuckyResult,
    );
  }
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
