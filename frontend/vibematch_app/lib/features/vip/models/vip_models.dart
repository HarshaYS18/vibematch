class VipCenterPayload {
  const VipCenterPayload({
    required this.lifetimeRechargeCoinExp,
    required this.monthlyRechargeCoinExp,
    required this.vip,
    required this.svip,
  });

  final int lifetimeRechargeCoinExp;
  final int monthlyRechargeCoinExp;
  final VipProgress vip;
  final VipProgress svip;

  factory VipCenterPayload.fromEconomyJson(Map<String, dynamic> json) {
    final wallet = json['wallet'];
    final source = wallet is Map<String, dynamic> ? wallet : json;
    return VipCenterPayload(
      lifetimeRechargeCoinExp: int.tryParse(source['lifetime_recharge_coin_exp']?.toString() ?? '') ?? 0,
      monthlyRechargeCoinExp: int.tryParse(source['monthly_recharge_coin_exp']?.toString() ?? '') ?? 0,
      vip: VipProgress.fromJson((source['vip'] as Map<String, dynamic>?) ?? const <String, dynamic>{}),
      svip: VipProgress.fromJson((source['svip'] as Map<String, dynamic>?) ?? const <String, dynamic>{}),
    );
  }

  static const empty = VipCenterPayload(
    lifetimeRechargeCoinExp: 0,
    monthlyRechargeCoinExp: 0,
    vip: VipProgress.emptyVip,
    svip: VipProgress.emptySvip,
  );
}

class VipProgress {
  const VipProgress({
    required this.track,
    required this.label,
    required this.level,
    required this.maxLevel,
    required this.totalExp,
    required this.currentLevelStartExp,
    required this.nextLevelExp,
    required this.expIntoLevel,
    required this.expNeededForNextLevel,
    required this.progress,
    required this.isMaxLevel,
    required this.maxTotalExp,
    required this.maxRupeeValue,
    required this.curveType,
    required this.thresholds,
  });

  final String track;
  final String label;
  final int level;
  final int maxLevel;
  final int totalExp;
  final int currentLevelStartExp;
  final int nextLevelExp;
  final int expIntoLevel;
  final int expNeededForNextLevel;
  final double progress;
  final bool isMaxLevel;
  final int maxTotalExp;
  final int maxRupeeValue;
  final String curveType;
  final List<VipLevelThreshold> thresholds;

  static const emptyVip = VipProgress(
    track: 'vip',
    label: 'VIP Lv',
    level: 0,
    maxLevel: 50,
    totalExp: 0,
    currentLevelStartExp: 0,
    nextLevelExp: 0,
    expIntoLevel: 0,
    expNeededForNextLevel: 0,
    progress: 0,
    isMaxLevel: false,
    maxTotalExp: 0,
    maxRupeeValue: 0,
    curveType: 'explicit_threshold_table',
    thresholds: <VipLevelThreshold>[],
  );

  static const emptySvip = VipProgress(
    track: 'svip',
    label: 'SVIP Lv',
    level: 0,
    maxLevel: 10,
    totalExp: 0,
    currentLevelStartExp: 0,
    nextLevelExp: 0,
    expIntoLevel: 0,
    expNeededForNextLevel: 0,
    progress: 0,
    isMaxLevel: false,
    maxTotalExp: 0,
    maxRupeeValue: 0,
    curveType: 'explicit_threshold_table',
    thresholds: <VipLevelThreshold>[],
  );

  factory VipProgress.fromJson(Map<String, dynamic> json) {
    final rawThresholds = json['level_thresholds'];
    return VipProgress(
      track: json['track']?.toString() ?? 'vip',
      label: json['label']?.toString() ?? 'VIP Lv',
      level: int.tryParse(json['level']?.toString() ?? '') ?? 0,
      maxLevel: int.tryParse(json['max_level']?.toString() ?? '') ?? 0,
      totalExp: int.tryParse(json['total_exp']?.toString() ?? '') ?? 0,
      currentLevelStartExp: int.tryParse(json['current_level_start_exp']?.toString() ?? '') ?? 0,
      nextLevelExp: int.tryParse(json['next_level_exp']?.toString() ?? '') ?? 0,
      expIntoLevel: int.tryParse(json['exp_into_level']?.toString() ?? '') ?? 0,
      expNeededForNextLevel: int.tryParse(json['exp_needed_for_next_level']?.toString() ?? '') ?? 0,
      progress: (double.tryParse(json['progress']?.toString() ?? '') ?? 0).clamp(0, 1).toDouble(),
      isMaxLevel: json['is_max_level'] == true,
      maxTotalExp: int.tryParse(json['max_total_exp']?.toString() ?? '') ?? 0,
      maxRupeeValue: int.tryParse(json['max_rupee_value']?.toString() ?? '') ?? 0,
      curveType: json['curve_type']?.toString() ?? 'explicit_threshold_table',
      thresholds: rawThresholds is List
          ? rawThresholds.whereType<Map<String, dynamic>>().map(VipLevelThreshold.fromJson).toList(growable: false)
          : const <VipLevelThreshold>[],
    );
  }
}

class VipLevelThreshold {
  const VipLevelThreshold({
    required this.level,
    required this.requiredExp,
    required this.requiredCoinRecharge,
    required this.requiredRupeeValue,
  });

  final int level;
  final int requiredExp;
  final int requiredCoinRecharge;
  final int requiredRupeeValue;

  factory VipLevelThreshold.fromJson(Map<String, dynamic> json) {
    return VipLevelThreshold(
      level: int.tryParse(json['level']?.toString() ?? '') ?? 0,
      requiredExp: int.tryParse(json['required_exp']?.toString() ?? '') ?? 0,
      requiredCoinRecharge: int.tryParse(json['required_coin_recharge']?.toString() ?? '') ?? 0,
      requiredRupeeValue: int.tryParse(json['required_rupee_value']?.toString() ?? '') ?? 0,
    );
  }
}

String compactRupees(int value) {
  if (value >= 10000000) return '₹${(value / 10000000).toStringAsFixed(value % 10000000 == 0 ? 0 : 1)}Cr';
  if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(value % 100000 == 0 ? 0 : 1)}L';
  if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
  return '₹$value';
}

String compactCoins(int value) {
  if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(value % 1000000000 == 0 ? 0 : 1)}B';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
  return '$value';
}
