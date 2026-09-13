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

    final vip = _map(json['vip']);
    final svip = _map(json['svip']);

    // UserIdentitySnapshot may receive either an aggregate user/VIP payload or
    // an already-extracted VIP object. Support both shapes here so VIP state
    // has one normalization path throughout the app.
    final isAggregatePayload =
        json.containsKey('vip') ||
        json.containsKey('svip') ||
        json.containsKey('vip_level') ||
        json.containsKey('vipLevel') ||
        json.containsKey('svip_level') ||
        json.containsKey('svipLevel');

    final directVipLevel = isAggregatePayload ? null : json['level'];
    final directVipActive = isAggregatePayload
        ? null
        : json['is_active'] ?? json['isActive'] ?? json['active'];

    final vipLevel = _clamp(
      _firstInt([
        json['vip_level'],
        json['vipLevel'],
        vip['level'],
        directVipLevel,
      ]),
      max: 50,
    );
    final svipLevel = _clamp(
      _firstInt([json['svip_level'], json['svipLevel'], svip['level']]),
      max: 10,
    );
    final colors =
        json['name_gradient_colors'] ?? json['nameGradientColors'];

    return UserVipSummary(
      vipLevel: vipLevel,
      svipLevel: svipLevel,
      vipIsActive: _bool(
        json['vip_is_active'] ?? json['vipIsActive'] ?? directVipActive,
        fallback: vipLevel > 0,
      ),
      svipIsActive: _bool(
        json['svip_is_active'] ?? json['svipIsActive'],
        fallback: svipLevel > 0,
      ),
      svipExpiresAt: _date(
        json['svip_expires_at'] ??
            json['svipExpiresAt'] ??
            svip['expires_at'] ??
            svip['expiresAt'],
      ),
      nameGradientKey:
          (json['name_gradient_key'] ?? json['nameGradientKey'] ?? 'default')
              .toString(),
      nameGradientColors: colors is List
          ? colors
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
    );
  }

  const UserVipSummary.empty()
      : vipLevel = 0,
        svipLevel = 0,
        vipIsActive = false,
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
      'vip': {'level': vipLevel},
      'svip': {'level': svipLevel},
    };
  }

  bool get hasActiveSvipGradient =>
      svipIsActive && svipLevel > 0 && nameGradientColors.length >= 2;
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
    final levels = _map(json['levels']);

    final lifetimeSendExp = _firstInt([
      json['lifetime_send_exp'],
      json['send_exp'],
      sent['total_exp'],
      levels['send_exp'],
      json['lifetime_coins_spent'],
    ]);
    final lifetimeReceiveExp = _firstInt([
      json['lifetime_receive_exp'],
      json['receive_exp'],
      received['total_exp'],
      levels['receive_exp'],
      json['lifetime_coins_received_as_gifts'],
    ]);

    return UserWalletSummary(
      coinBalance: _nonNegativeInt(json['coin_balance'] ?? json['coins']),
      rubyBalance: _nonNegativeInt(json['ruby_balance'] ?? json['rubies']),
      lifetimeCoinsSpent: _nonNegativeInt(json['lifetime_coins_spent']),
      lifetimeCoinsReceivedAsGifts: _nonNegativeInt(
        json['lifetime_coins_received_as_gifts'],
      ),
      lifetimeRubiesEarned: _nonNegativeInt(json['lifetime_rubies_earned']),
      monthlyGiftCoinsSent: _firstInt([
        json['monthly_gift_coins_sent'],
        json['monthly_sent_coins'],
      ]),
      monthlyGiftCoinsReceived: _firstInt([
        json['monthly_gift_coins_received'],
        json['monthly_received_coins'],
      ]),
      lifetimeSendExp: lifetimeSendExp,
      lifetimeReceiveExp: lifetimeReceiveExp,
      sendLevel: _firstInt([
        json['sent_level'],
        json['send_level'],
        json['sending_level'],
        sent['level'],
        levels['send_level'],
        levels['sent_level'],
      ]),
      receiveLevel: _firstInt([
        json['receive_level'],
        json['received_level'],
        json['receiving_level'],
        received['level'],
        levels['receive_level'],
        levels['received_level'],
      ]),
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
      'sent_level': sendLevel,
      'send_level': sendLevel,
      'receive_level': receiveLevel,
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

int _firstInt(List<dynamic> values) {
  for (final value in values) {
    final parsed = _nullableInt(value);
    if (parsed != null) return parsed < 0 ? 0 : parsed;
  }
  return 0;
}

int _nonNegativeInt(dynamic value) {
  final parsed = _nullableInt(value) ?? 0;
  return parsed < 0 ? 0 : parsed;
}

int? _nullableInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

int _clamp(int value, {required int max}) {
  if (value < 0) return 0;
  if (value > max) return max;
  return value;
}

bool _bool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return fallback;
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}
