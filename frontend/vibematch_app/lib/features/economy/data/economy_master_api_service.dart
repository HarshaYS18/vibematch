import 'dart:convert';

import 'package:vibematch_app/foundation/networking/feature_http_compat.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';
import '../../profile/models/vip_wallet_models.dart';

class EconomyMasterApiService {
  const EconomyMasterApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<EconomyMasterSnapshot> getMyMasterEconomy() async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/economy/me/master')),
      headers: _headers(),
    );
    _throwIfBad(response, 'Failed to load economy master');
    final snapshot = EconomyMasterSnapshot.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    await publishToCurrentUser(snapshot);
    return snapshot;
  }

  Future<EconomyPublicCardSnapshot> getPublicCard(int publicUserId) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/economy/users/$publicUserId/public-card')),
      headers: _headers(),
    );
    _throwIfBad(response, 'Failed to load public economy card');
    return EconomyPublicCardSnapshot.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> publishToCurrentUser(EconomyMasterSnapshot snapshot) async {
    final currentUser = authApiService.cachedUser;
    if (currentUser == null || currentUser.id != snapshot.userId) return;

    final nextWallet = UserWalletSummary(
      coinBalance: snapshot.walletCoins,
      rubyBalance: snapshot.walletRubies,
      lifetimeCoinsSpent: currentUser.wallet.lifetimeCoinsSpent,
      lifetimeCoinsReceivedAsGifts: currentUser.wallet.lifetimeCoinsReceivedAsGifts,
      lifetimeRubiesEarned: currentUser.wallet.lifetimeRubiesEarned,
      monthlyGiftCoinsSent: snapshot.monthlySentCoins,
      monthlyGiftCoinsReceived: snapshot.monthlyReceivedCoins,
      lifetimeSendExp: snapshot.sendExp,
      lifetimeReceiveExp: snapshot.receiveExp,
      sendLevel: snapshot.sendLevel,
      receiveLevel: snapshot.receiveLevel,
    );

    final nextVip = UserVipSummary(
      vipLevel: snapshot.vipLevel,
      svipLevel: snapshot.svipLevel,
      vipIsActive: snapshot.vipStatus == 'active' || snapshot.vipLevel > 0,
      svipIsActive: snapshot.svipStatus == 'active' || snapshot.svipLevel > 0,
      svipExpiresAt: snapshot.svipExpiresAt == null
          ? currentUser.vip.svipExpiresAt
          : DateTime.tryParse(snapshot.svipExpiresAt!),
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
    return {'Authorization': 'Bearer $token'};
  }

  void _throwIfBad(http.Response response, String label) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$label (${response.statusCode}): ${response.body}');
    }
  }
}

class EconomyMasterSnapshot {
  const EconomyMasterSnapshot({
    required this.userId,
    required this.publicUserId,
    required this.walletCoins,
    required this.walletRubies,
    required this.withdrawableRubies,
    required this.pendingWithdrawRubies,
    required this.vipLevel,
    required this.vipStatus,
    required this.svipLevel,
    required this.svipStatus,
    required this.svipExpiresAt,
    required this.sendLevel,
    required this.sendExp,
    required this.receiveLevel,
    required this.receiveExp,
    required this.monthlySentCoins,
    required this.monthlyReceivedCoins,
  });

  final int userId;
  final int publicUserId;
  final int walletCoins;
  final int walletRubies;
  final int withdrawableRubies;
  final int pendingWithdrawRubies;
  final int vipLevel;
  final String vipStatus;
  final int svipLevel;
  final String svipStatus;
  final String? svipExpiresAt;
  final int sendLevel;
  final int sendExp;
  final int receiveLevel;
  final int receiveExp;
  final int monthlySentCoins;
  final int monthlyReceivedCoins;

  factory EconomyMasterSnapshot.fromJson(Map<String, dynamic> json) {
    final user = _map(json['user']);
    final wallet = _map(json['wallet']);
    final vip = _map(json['vip']);
    final svip = _map(json['svip']);
    final levels = _map(json['levels']);
    final contribution = _map(json['contribution']);
    return EconomyMasterSnapshot(
      userId: _int(user['user_id']),
      publicUserId: _int(user['public_user_id']),
      walletCoins: _int(wallet['coins']),
      walletRubies: _int(wallet['rubies']),
      withdrawableRubies: _int(wallet['withdrawable_rubies']),
      pendingWithdrawRubies: _int(wallet['pending_withdraw_rubies']),
      vipLevel: _firstPositive([vip['level'], vip['vip_level']]),
      vipStatus: vip['status'] as String? ?? '',
      svipLevel: _firstPositive([svip['level'], svip['svip_level']]),
      svipStatus: svip['status'] as String? ?? '',
      svipExpiresAt: svip['expires_at'] as String?,
      sendLevel: _int(levels['send_level']),
      sendExp: _int(levels['send_exp']),
      receiveLevel: _int(levels['receive_level']),
      receiveExp: _int(levels['receive_exp']),
      monthlySentCoins: _int(contribution['monthly_sent_coins']),
      monthlyReceivedCoins: _int(contribution['monthly_received_coins']),
    );
  }
}

class EconomyPublicCardSnapshot {
  const EconomyPublicCardSnapshot({
    required this.publicUserId,
    required this.displayName,
    required this.avatarUrl,
    required this.vipLevel,
    required this.svipLevel,
    required this.sendLevel,
    required this.receiveLevel,
    required this.monthlySentCoins,
    required this.monthlyReceivedCoins,
  });

  final int publicUserId;
  final String displayName;
  final String? avatarUrl;
  final int vipLevel;
  final int svipLevel;
  final int sendLevel;
  final int receiveLevel;
  final int monthlySentCoins;
  final int monthlyReceivedCoins;

  factory EconomyPublicCardSnapshot.fromJson(Map<String, dynamic> json) {
    final user = _map(json['user']);
    final vip = _map(json['vip']);
    final svip = _map(json['svip']);
    final levels = _map(json['levels']);
    final contribution = _map(json['contribution']);
    return EconomyPublicCardSnapshot(
      publicUserId: _int(user['public_user_id']),
      displayName: user['display_name'] as String? ?? '',
      avatarUrl: user['avatar_url'] as String?,
      vipLevel: _firstPositive([vip['level'], vip['vip_level']]),
      svipLevel: _firstPositive([svip['level'], svip['svip_level']]),
      sendLevel: _int(levels['send_level']),
      receiveLevel: _int(levels['receive_level']),
      monthlySentCoins: _int(contribution['monthly_sent_coins']),
      monthlyReceivedCoins: _int(contribution['monthly_received_coins']),
    );
  }
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
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
