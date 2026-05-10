import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class CoinSalesApiService {
  const CoinSalesApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<List<CoinSupplyPoolSummary>> mySupplyPools() async {
    final token = _token();
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/coin-sales/my-supply-pools')),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load supply pools (${response.statusCode}): ${response.body}');
    }
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.whereType<Map<String, dynamic>>().map(CoinSupplyPoolSummary.fromJson).toList(growable: false);
  }

  Future<CoinSupplyPoolSummary> grantSupply({
    required int targetPublicUserId,
    required String poolType,
    required int amount,
    required String reason,
  }) async {
    final token = _token();
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/coin-sales/admin/grant-supply')),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'target_public_user_id': targetPublicUserId,
        'pool_type': poolType,
        'amount': amount,
        'reason': reason.trim(),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to grant supply (${response.statusCode}): ${response.body}');
    }
    return CoinSupplyPoolSummary.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<CoinSaleResult> sellToUser({
    required int targetPublicUserId,
    required int coinAmount,
    required int paymentAmount,
    required String paymentCurrency,
    required int sourcePoolId,
    required String reason,
    String? proofUrl,
  }) async {
    final token = _token();
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/coin-sales/sell-to-user')),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'target_public_user_id': targetPublicUserId,
        'coin_amount': coinAmount,
        'payment_amount': paymentAmount,
        'payment_currency': paymentCurrency.trim().isEmpty ? 'INR' : paymentCurrency.trim(),
        'proof_url': proofUrl,
        'source_pool_id': sourcePoolId,
        'reason': reason.trim(),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to sell coins (${response.statusCode}): ${response.body}');
    }
    return CoinSaleResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  String _token() {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before using coin sales.');
    }
    return token;
  }
}

class CoinSupplyPoolSummary {
  const CoinSupplyPoolSummary({
    required this.id,
    required this.ownerUserId,
    required this.poolType,
    required this.balance,
    required this.reservedBalance,
    required this.status,
  });

  final int id;
  final int? ownerUserId;
  final String poolType;
  final int balance;
  final int reservedBalance;
  final String status;

  factory CoinSupplyPoolSummary.fromJson(Map<String, dynamic> json) {
    return CoinSupplyPoolSummary(
      id: _int(json['id']),
      ownerUserId: _nullableInt(json['owner_user_id']),
      poolType: json['pool_type']?.toString() ?? 'SELLER_SUPPLY_POOL',
      balance: _int(json['balance']),
      reservedBalance: _int(json['reserved_balance']),
      status: json['status']?.toString() ?? 'ACTIVE',
    );
  }
}

class CoinSaleResult {
  const CoinSaleResult({
    required this.orderId,
    required this.sellerUserId,
    required this.buyerUserId,
    required this.buyerPublicUserId,
    required this.sourcePoolId,
    required this.coinAmount,
    required this.buyerWalletCoinBalance,
    required this.sellerPoolBalance,
    required this.deliveryStatus,
    required this.note,
  });

  final int orderId;
  final int sellerUserId;
  final int buyerUserId;
  final int buyerPublicUserId;
  final int sourcePoolId;
  final int coinAmount;
  final int buyerWalletCoinBalance;
  final int sellerPoolBalance;
  final String deliveryStatus;
  final String note;

  factory CoinSaleResult.fromJson(Map<String, dynamic> json) {
    return CoinSaleResult(
      orderId: _int(json['order_id']),
      sellerUserId: _int(json['seller_user_id']),
      buyerUserId: _int(json['buyer_user_id']),
      buyerPublicUserId: _int(json['buyer_public_user_id']),
      sourcePoolId: _int(json['source_pool_id']),
      coinAmount: _int(json['coin_amount']),
      buyerWalletCoinBalance: _int(json['buyer_wallet_coin_balance']),
      sellerPoolBalance: _int(json['seller_pool_balance']),
      deliveryStatus: json['delivery_status']?.toString() ?? 'DELIVERED',
      note: json['note']?.toString() ?? '',
    );
  }
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
