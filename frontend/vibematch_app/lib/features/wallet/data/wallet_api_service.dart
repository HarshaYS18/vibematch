import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class WalletApiService {
  const WalletApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<VmWallet> getWallet() async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/wallet/me')),
      headers: _headers(),
    );
    _throwIfBad(response, 'Failed to load wallet');
    return VmWallet.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<VmWalletLedgerEntry>> getLedger({int limit = 50}) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/wallet/ledger?limit=$limit')),
      headers: _headers(),
    );
    _throwIfBad(response, 'Failed to load wallet ledger');
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(VmWalletLedgerEntry.fromJson)
        .toList();
  }

  Future<VmWallet> recharge({required int amountInr}) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/wallet/recharge')),
      headers: _headers(),
      body: jsonEncode({
        'amount_inr': amountInr,
        'provider': 'mvp',
        'provider_reference': 'mvp_${DateTime.now().millisecondsSinceEpoch}',
      }),
    );
    _throwIfBad(response, 'Recharge failed');
    return VmWallet.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<VmWallet> convertRuby({required int rubyAmount}) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/wallet/ruby/convert')),
      headers: _headers(),
      body: jsonEncode({'ruby_amount': rubyAmount}),
    );
    _throwIfBad(response, 'Ruby conversion failed');
    return VmWallet.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

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

class VmWallet {
  const VmWallet({
    required this.userId,
    required this.coinBalance,
    required this.rubyBalance,
    required this.lifetimeCoinIn,
    required this.lifetimeCoinOut,
    required this.lifetimeRubyIn,
    required this.lifetimeRubyOut,
    required this.lifetimeRechargeCoins,
    required this.monthlyRechargeCoins,
    required this.monthlyRechargePeriod,
    required this.vipLevel,
    required this.svipLevel,
    required this.svipExpiresAt,
    required this.coinPriceText,
    required this.vipMaxLevel,
    required this.svipMaxLevel,
    required this.vipMaxLifetimeRechargeCoins,
    required this.svipMaxMonthlyRechargeCoins,
    required this.vipProgressPercent,
    required this.svipProgressPercent,
    required this.isFrozen,
    required this.freezeReason,
  });

  final int userId;
  final int coinBalance;
  final int rubyBalance;
  final int lifetimeCoinIn;
  final int lifetimeCoinOut;
  final int lifetimeRubyIn;
  final int lifetimeRubyOut;
  final int lifetimeRechargeCoins;
  final int monthlyRechargeCoins;
  final String? monthlyRechargePeriod;
  final int vipLevel;
  final int svipLevel;
  final String? svipExpiresAt;
  final String coinPriceText;
  final int vipMaxLevel;
  final int svipMaxLevel;
  final int vipMaxLifetimeRechargeCoins;
  final int svipMaxMonthlyRechargeCoins;
  final double vipProgressPercent;
  final double svipProgressPercent;
  final bool isFrozen;
  final String? freezeReason;

  factory VmWallet.fromJson(Map<String, dynamic> json) {
    return VmWallet(
      userId: _int(json['user_id']),
      coinBalance: _int(json['coin_balance']),
      rubyBalance: _int(json['ruby_balance']),
      lifetimeCoinIn: _int(json['lifetime_coin_in']),
      lifetimeCoinOut: _int(json['lifetime_coin_out']),
      lifetimeRubyIn: _int(json['lifetime_ruby_in']),
      lifetimeRubyOut: _int(json['lifetime_ruby_out']),
      lifetimeRechargeCoins: _int(json['lifetime_recharge_coins']),
      monthlyRechargeCoins: _int(json['monthly_recharge_coins']),
      monthlyRechargePeriod: json['monthly_recharge_period'] as String?,
      vipLevel: _int(json['vip_level']),
      svipLevel: _int(json['svip_level']),
      svipExpiresAt: json['svip_expires_at'] as String?,
      coinPriceText: json['coin_price_text'] as String? ?? '1 lakh coins = ₹100',
      vipMaxLevel: _int(json['vip_max_level']),
      svipMaxLevel: _int(json['svip_max_level']),
      vipMaxLifetimeRechargeCoins: _int(json['vip_max_lifetime_recharge_coins']),
      svipMaxMonthlyRechargeCoins: _int(json['svip_max_monthly_recharge_coins']),
      vipProgressPercent: _double(json['vip_progress_percent']),
      svipProgressPercent: _double(json['svip_progress_percent']),
      isFrozen: json['is_frozen'] as bool? ?? false,
      freezeReason: json['freeze_reason'] as String?,
    );
  }
}

class VmWalletLedgerEntry {
  const VmWalletLedgerEntry({
    required this.id,
    required this.currency,
    required this.direction,
    required this.source,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.reason,
    required this.createdAt,
  });

  final int id;
  final String currency;
  final String direction;
  final String source;
  final int amount;
  final int balanceBefore;
  final int balanceAfter;
  final String? reason;
  final String createdAt;

  factory VmWalletLedgerEntry.fromJson(Map<String, dynamic> json) {
    return VmWalletLedgerEntry(
      id: _int(json['id']),
      currency: json['currency'] as String? ?? 'coins',
      direction: json['direction'] as String? ?? 'credit',
      source: json['source'] as String? ?? 'adjustment',
      amount: _int(json['amount']),
      balanceBefore: _int(json['balance_before']),
      balanceAfter: _int(json['balance_after']),
      reason: json['reason'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _double(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
