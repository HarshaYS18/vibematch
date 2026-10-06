import 'dart:convert';

import 'package:vibematch_app/foundation/networking/feature_http_compat.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';
import '../../profile/models/vip_wallet_models.dart';

class WalletApiService {
  const WalletApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<VmWallet> getWallet() async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/wallets/me')),
      headers: _headers(),
    );
    _throwIfBad(response, 'Failed to load wallet');
    final wallet = VmWallet.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    await _publishWalletSnapshot(wallet);
    return wallet;
  }

  Future<List<VmWalletLedgerEntry>> getLedger({int limit = 50}) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/wallets/ledger?limit=$limit')),
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
    final prefs = await SharedPreferences.getInstance();
    final pendingKey = 'wallet_recharge_pending_$amountInr';
    var providerReference = prefs.getString(pendingKey);
    if (providerReference == null || providerReference.trim().isEmpty) {
      providerReference = 'mvp_${const Uuid().v4()}';
      await prefs.setString(pendingKey, providerReference);
    }

    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/wallets/recharge')),
      headers: _headers(),
      body: jsonEncode({
        'amount_inr': amountInr,
        'provider': 'mvp',
        'provider_reference': providerReference,
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await prefs.remove(pendingKey);
      final wallet = VmWallet.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      await _publishWalletSnapshot(wallet);
      return wallet;
    }
    if (response.statusCode >= 400 && response.statusCode < 500) {
      await prefs.remove(pendingKey);
    }
    _throwIfBad(response, 'Recharge failed');
    throw StateError('Unreachable recharge response');
  }

  Future<VmWallet> convertRuby({required int rubyAmount}) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingKey = 'wallet_convert_pending_$rubyAmount';
    var requestId = prefs.getString(pendingKey);
    if (requestId == null || requestId.trim().isEmpty) {
      requestId = const Uuid().v4();
      await prefs.setString(pendingKey, requestId);
    }

    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/wallets/rubies/convert')),
      headers: _headers(),
      body: jsonEncode({
        'ruby_amount': rubyAmount,
        'request_id': requestId,
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await prefs.remove(pendingKey);
      final wallet = VmWallet.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      await _publishWalletSnapshot(wallet);
      return wallet;
    }
    if (response.statusCode >= 400 && response.statusCode < 500) {
      await prefs.remove(pendingKey);
    }
    _throwIfBad(response, 'Ruby conversion failed');
    throw StateError('Unreachable ruby conversion response');
  }

  Future<void> _publishWalletSnapshot(VmWallet wallet) async {
    final currentUser = authApiService.cachedUser;
    if (currentUser == null || currentUser.id != wallet.userId) return;

    final nextWallet = UserWalletSummary(
      coinBalance: wallet.coinBalance,
      rubyBalance: wallet.rubyBalance,
      lifetimeCoinsSpent: wallet.lifetimeCoinsSpent,
      lifetimeCoinsReceivedAsGifts: wallet.lifetimeCoinsReceivedAsGifts,
      lifetimeRubiesEarned: wallet.lifetimeRubiesEarned,
      monthlyGiftCoinsSent: wallet.monthlyGiftCoinsSent,
      monthlyGiftCoinsReceived: wallet.monthlyGiftCoinsReceived,
      lifetimeSendExp: wallet.lifetimeSendExp,
      lifetimeReceiveExp: wallet.lifetimeReceiveExp,
      sendLevel: wallet.sentLevel,
      receiveLevel: wallet.receiveLevel,
    );
    final parsedSvipExpiry = wallet.svipExpiresAt == null
        ? null
        : DateTime.tryParse(wallet.svipExpiresAt!);
    final nextVip = UserVipSummary(
      vipLevel: wallet.vipLevel,
      svipLevel: wallet.svipLevel,
      vipIsActive: wallet.vipLevel > 0,
      svipIsActive: wallet.svipLevel > 0,
      svipExpiresAt: parsedSvipExpiry ?? currentUser.vip.svipExpiresAt,
      nameGradientKey: currentUser.vip.nameGradientKey,
      nameGradientColors: currentUser.vip.nameGradientColors,
    );
    await authApiService.persistCurrentUser(
      currentUser.copyWith(
        wallet: nextWallet,
        vip: nextVip,
        updatedAt: DateTime.now(),
      ),
    );
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
    required this.withdrawableRubies,
    required this.pendingWithdrawRubies,
    required this.lifetimeCoinsSpent,
    required this.lifetimeCoinsReceivedAsGifts,
    required this.lifetimeRubiesEarned,
    required this.lifetimeRechargeCoins,
    required this.monthlyRechargeCoins,
    required this.monthlyRechargePeriod,
    required this.monthlyGiftCoinsSent,
    required this.monthlyGiftCoinsReceived,
    required this.lifetimeSendExp,
    required this.lifetimeReceiveExp,
    required this.sentLevel,
    required this.receiveLevel,
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
  });

  final int userId;
  final int coinBalance;
  final int rubyBalance;
  final int withdrawableRubies;
  final int pendingWithdrawRubies;
  final int lifetimeCoinsSpent;
  final int lifetimeCoinsReceivedAsGifts;
  final int lifetimeRubiesEarned;
  final int lifetimeRechargeCoins;
  final int monthlyRechargeCoins;
  final String monthlyRechargePeriod;
  final int monthlyGiftCoinsSent;
  final int monthlyGiftCoinsReceived;
  final int lifetimeSendExp;
  final int lifetimeReceiveExp;
  final int sentLevel;
  final int receiveLevel;
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

  factory VmWallet.fromJson(Map<String, dynamic> json) => VmWallet(
    userId: _int(json['user_id']),
    coinBalance: _int(json['coin_balance']),
    rubyBalance: _int(json['ruby_balance']),
    withdrawableRubies: _int(json['withdrawable_rubies']),
    pendingWithdrawRubies: _int(json['pending_withdraw_rubies']),
    lifetimeCoinsSpent: _int(json['lifetime_coins_spent']),
    lifetimeCoinsReceivedAsGifts: _int(
      json['lifetime_coins_received_as_gifts'],
    ),
    lifetimeRubiesEarned: _int(json['lifetime_rubies_earned']),
    lifetimeRechargeCoins: _int(json['lifetime_recharge_coins']),
    monthlyRechargeCoins: _int(json['monthly_recharge_coins']),
    monthlyRechargePeriod: json['monthly_recharge_period'] as String? ?? '',
    monthlyGiftCoinsSent: _int(json['monthly_gift_coins_sent']),
    monthlyGiftCoinsReceived: _int(json['monthly_gift_coins_received']),
    lifetimeSendExp: _firstPositive([
      json['lifetime_send_exp'],
      _map(json['sent'])['total_exp'],
    ]),
    lifetimeReceiveExp: _firstPositive([
      json['lifetime_receive_exp'],
      _map(json['received'])['total_exp'],
    ]),
    sentLevel: _firstPositive([
      json['sent_level'],
      _map(json['sent'])['level'],
    ]),
    receiveLevel: _firstPositive([
      json['receive_level'],
      _map(json['received'])['level'],
    ]),
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
  );

  VmWallet copyWith({
    int? coinBalance,
    int? rubyBalance,
    int? withdrawableRubies,
    int? pendingWithdrawRubies,
    int? lifetimeCoinsSpent,
    int? lifetimeCoinsReceivedAsGifts,
    int? lifetimeRubiesEarned,
    int? lifetimeRechargeCoins,
    int? monthlyRechargeCoins,
    String? monthlyRechargePeriod,
    int? monthlyGiftCoinsSent,
    int? monthlyGiftCoinsReceived,
    int? lifetimeSendExp,
    int? lifetimeReceiveExp,
    int? sentLevel,
    int? receiveLevel,
    int? vipLevel,
    int? svipLevel,
    String? svipExpiresAt,
    String? coinPriceText,
    int? vipMaxLevel,
    int? svipMaxLevel,
    int? vipMaxLifetimeRechargeCoins,
    int? svipMaxMonthlyRechargeCoins,
    double? vipProgressPercent,
    double? svipProgressPercent,
  }) {
    return VmWallet(
      userId: userId,
      coinBalance: coinBalance ?? this.coinBalance,
      rubyBalance: rubyBalance ?? this.rubyBalance,
      withdrawableRubies: withdrawableRubies ?? this.withdrawableRubies,
      pendingWithdrawRubies:
          pendingWithdrawRubies ?? this.pendingWithdrawRubies,
      lifetimeCoinsSpent: lifetimeCoinsSpent ?? this.lifetimeCoinsSpent,
      lifetimeCoinsReceivedAsGifts:
          lifetimeCoinsReceivedAsGifts ?? this.lifetimeCoinsReceivedAsGifts,
      lifetimeRubiesEarned: lifetimeRubiesEarned ?? this.lifetimeRubiesEarned,
      lifetimeRechargeCoins:
          lifetimeRechargeCoins ?? this.lifetimeRechargeCoins,
      monthlyRechargeCoins: monthlyRechargeCoins ?? this.monthlyRechargeCoins,
      monthlyRechargePeriod:
          monthlyRechargePeriod ?? this.monthlyRechargePeriod,
      monthlyGiftCoinsSent: monthlyGiftCoinsSent ?? this.monthlyGiftCoinsSent,
      monthlyGiftCoinsReceived:
          monthlyGiftCoinsReceived ?? this.monthlyGiftCoinsReceived,
      lifetimeSendExp: lifetimeSendExp ?? this.lifetimeSendExp,
      lifetimeReceiveExp: lifetimeReceiveExp ?? this.lifetimeReceiveExp,
      sentLevel: sentLevel ?? this.sentLevel,
      receiveLevel: receiveLevel ?? this.receiveLevel,
      vipLevel: vipLevel ?? this.vipLevel,
      svipLevel: svipLevel ?? this.svipLevel,
      svipExpiresAt: svipExpiresAt ?? this.svipExpiresAt,
      coinPriceText: coinPriceText ?? this.coinPriceText,
      vipMaxLevel: vipMaxLevel ?? this.vipMaxLevel,
      svipMaxLevel: svipMaxLevel ?? this.svipMaxLevel,
      vipMaxLifetimeRechargeCoins:
          vipMaxLifetimeRechargeCoins ?? this.vipMaxLifetimeRechargeCoins,
      svipMaxMonthlyRechargeCoins:
          svipMaxMonthlyRechargeCoins ?? this.svipMaxMonthlyRechargeCoins,
      vipProgressPercent: vipProgressPercent ?? this.vipProgressPercent,
      svipProgressPercent: svipProgressPercent ?? this.svipProgressPercent,
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

  factory VmWalletLedgerEntry.fromJson(Map<String, dynamic> json) =>
      VmWalletLedgerEntry(
        id: _int(json['id']),
        currency: json['currency'] as String? ?? 'coin',
        direction: json['direction'] as String? ?? 'credit',
        source: json['source'] as String? ?? 'unknown',
        amount: _int(json['amount']),
        balanceBefore: _int(json['balance_before']),
        balanceAfter: _int(json['balance_after']),
        reason: json['reason'] as String?,
        createdAt: json['created_at'] as String? ?? '',
      );
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

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

int _firstPositive(List<Object?> values) {
  for (final value in values) {
    final parsed = _int(value);
    if (parsed > 0) return parsed;
  }
  return 0;
}
