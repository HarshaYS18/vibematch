class UserVipSummary {
  const UserVipSummary({
    required this.vipLevel,
    required this.svipLevel,
    required this.vipIsActive,
    required this.svipIsActive,
    required this.svipExpiresAt,
    required this.nameGradientKey,
    required this.nameGradientColors,
  });

  final int vipLevel;
  final int svipLevel;
  final bool vipIsActive;
  final bool svipIsActive;
  final DateTime? svipExpiresAt;
  final String nameGradientKey;
  final List<String> nameGradientColors;

  factory UserVipSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserVipSummary.empty();
    final colors = json['name_gradient_colors'];
    return UserVipSummary(
      vipLevel: _int(json['vip_level']),
      svipLevel: _int(json['svip_level']),
      vipIsActive: _bool(json['vip_is_active'], fallback: true),
      svipIsActive: _bool(json['svip_is_active']),
      svipExpiresAt: _date(json['svip_expires_at']),
      nameGradientKey: (json['name_gradient_key'] ?? 'default').toString(),
      nameGradientColors: colors is List ? colors.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList() : const <String>[],
    );
  }

  const UserVipSummary.empty()
      : vipLevel = 0,
        svipLevel = 0,
        vipIsActive = true,
        svipIsActive = false,
        svipExpiresAt = null,
        nameGradientKey = 'default',
        nameGradientColors = const <String>[];

  Map<String, dynamic> toJson() {
    return {
      'vip_level': vipLevel,
      'svip_level': svipLevel,
      'vip_is_active': vipIsActive,
      'svip_is_active': svipIsActive,
      'svip_expires_at': svipExpiresAt?.toIso8601String(),
      'name_gradient_key': nameGradientKey,
      'name_gradient_colors': nameGradientColors,
    };
  }
  bool get hasActiveSvipGradient => svipIsActive && svipLevel > 0 && nameGradientColors.length >= 2;
}

class UserWalletSummary {
  const UserWalletSummary({
    required this.coinBalance,
    required this.rubyBalance,
    required this.lifetimeCoinsSpent,
    required this.lifetimeCoinsReceivedAsGifts,
    required this.lifetimeRubiesEarned,
    required this.monthlyGiftCoinsSent,
    required this.monthlyGiftCoinsReceived,
    required this.lifetimeSendExp,
    required this.lifetimeReceiveExp,
    required this.sendLevel,
    required this.receiveLevel,
  });

  final int coinBalance;
  final int rubyBalance;
  final int lifetimeCoinsSpent;
  final int lifetimeCoinsReceivedAsGifts;
  final int lifetimeRubiesEarned;
  final int monthlyGiftCoinsSent;
  final int monthlyGiftCoinsReceived;
  final int lifetimeSendExp;
  final int lifetimeReceiveExp;
  final int sendLevel;
  final int receiveLevel;

  factory UserWalletSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserWalletSummary.empty();
    final sent = _map(json['sent']);
    final received = _map(json['received']);
    return UserWalletSummary(
      coinBalance: _int(json['coin_balance']),
      rubyBalance: _int(json['ruby_balance']),
      lifetimeCoinsSpent: _int(json['lifetime_coins_spent']),
      lifetimeCoinsReceivedAsGifts: _int(json['lifetime_coins_received_as_gifts']),
      lifetimeRubiesEarned: _int(json['lifetime_rubies_earned']),
      monthlyGiftCoinsSent: _int(json['monthly_gift_coins_sent']),
      monthlyGiftCoinsReceived: _int(json['monthly_gift_coins_received']),
      lifetimeSendExp: _int(json['lifetime_send_exp']) == 0 ? _int(json['lifetime_coins_spent']) : _int(json['lifetime_send_exp']),
      lifetimeReceiveExp: _int(json['lifetime_receive_exp']) == 0 ? _int(json['lifetime_coins_received_as_gifts']) : _int(json['lifetime_receive_exp']),
      sendLevel: _int(sent['level']),
      receiveLevel: _int(received['level']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'coin_balance': coinBalance,
      'ruby_balance': rubyBalance,
      'lifetime_coins_spent': lifetimeCoinsSpent,
      'lifetime_coins_received_as_gifts': lifetimeCoinsReceivedAsGifts,
      'lifetime_rubies_earned': lifetimeRubiesEarned,
      'monthly_gift_coins_sent': monthlyGiftCoinsSent,
      'monthly_gift_coins_received': monthlyGiftCoinsReceived,
      'lifetime_send_exp': lifetimeSendExp,
      'lifetime_receive_exp': lifetimeReceiveExp,
      'sent': {'level': sendLevel, 'total_exp': lifetimeSendExp},
      'received': {'level': receiveLevel, 'total_exp': lifetimeReceiveExp},
    };
  }

  const UserWalletSummary.empty()
      : coinBalance = 0,
        rubyBalance = 0,
        lifetimeCoinsSpent = 0,
        lifetimeCoinsReceivedAsGifts = 0,
        lifetimeRubiesEarned = 0,
        monthlyGiftCoinsSent = 0,
        monthlyGiftCoinsReceived = 0,
        lifetimeSendExp = 0,
        lifetimeReceiveExp = 0,
        sendLevel = 0,
        receiveLevel = 0;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

bool _bool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') return true;
    if (normalized == 'false' || normalized == '0' || normalized == 'no') return false;
  }
  return fallback;
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) return DateTime.tryParse(value);
  return null;
}

