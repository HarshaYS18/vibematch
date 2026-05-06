import 'package:flutter/material.dart';

enum FamilyTier {
  bronze,
  silver,
  gold,
  platinum;

  String get label => switch (this) {
        FamilyTier.bronze => 'Bronze',
        FamilyTier.silver => 'Silver',
        FamilyTier.gold => 'Gold',
        FamilyTier.platinum => 'Platinum',
      };

  String get difficultyLabel => switch (this) {
        FamilyTier.bronze => 'Easy',
        FamilyTier.silver => 'Hard',
        FamilyTier.gold => 'Very hard',
        FamilyTier.platinum => 'Insane',
      };

  IconData get icon => switch (this) {
        FamilyTier.bronze => Icons.workspace_premium_rounded,
        FamilyTier.silver => Icons.shield_rounded,
        FamilyTier.gold => Icons.emoji_events_rounded,
        FamilyTier.platinum => Icons.diamond_rounded,
      };

  List<Color> get colors => switch (this) {
        FamilyTier.bronze => const [Color(0xFFB7791F), Color(0xFFE8B86B)],
        FamilyTier.silver => const [Color(0xFF7E8A99), Color(0xFFE3E8EF)],
        FamilyTier.gold => const [Color(0xFFC98910), Color(0xFFFFD95C)],
        FamilyTier.platinum => const [Color(0xFF4B5563), Color(0xFFDDEBFF)],
      };
}

class FamilyLevelConfig {
  const FamilyLevelConfig({
    required this.level,
    required this.requiredTotalExp,
    required this.tier,
    required this.maxMembers,
    required this.adminCapacity,
    this.minimumVipLabel,
    this.rewardIds = const [],
  });

  final int level;
  final int requiredTotalExp;
  final FamilyTier tier;
  final int maxMembers;
  final int adminCapacity;
  final String? minimumVipLabel;
  final List<String> rewardIds;
}

class FamilyExpRulesConfig {
  const FamilyExpRulesConfig({
    required this.timeExpPerBlock,
    required this.timeMinutesPerBlock,
    required this.maxDailyTimeExp,
    required this.coinsPerGiftExpBlock,
    required this.giftExpPerCoinBlock,
  });

  final int timeExpPerBlock;
  final int timeMinutesPerBlock;
  final int maxDailyTimeExp;
  final int coinsPerGiftExpBlock;
  final int giftExpPerCoinBlock;

  String get giftRuleLabel =>
      'Every $coinsPerGiftExpBlock coins spent on gifts gives $giftExpPerCoinBlock family EXP.';

  String get timeRuleLabel =>
      'Each member can contribute up to $maxDailyTimeExp time EXP per day by spending time in family activity.';
}

class FamilyProgramConfig {
  const FamilyProgramConfig({
    required this.levels,
    required this.expRules,
  });

  final List<FamilyLevelConfig> levels;
  final FamilyExpRulesConfig expRules;

  int get maxLevel => levels.isEmpty ? 1 : levels.last.level;

  factory FamilyProgramConfig.fromRemoteConfig(Map<String, dynamic> json) {
    final levels = _parseLevels(json['levels']);
    final expRules = _parseExpRules(json['exp_rules']);
    return FamilyProgramConfig(
      levels: levels.isEmpty ? FamilyLevelEngine.defaultProgramConfig.levels : levels,
      expRules: expRules ?? FamilyLevelEngine.defaultProgramConfig.expRules,
    );
  }

  static List<FamilyLevelConfig> _parseLevels(Object? rawLevels) {
    if (rawLevels is! List) return const [];

    final levels = <FamilyLevelConfig>[];
    for (final rawLevel in rawLevels) {
      if (rawLevel is! Map) continue;

      final level = _readInt(rawLevel['level']);
      final requiredExp = _readInt(rawLevel['required_total_exp']);
      if (level == null || requiredExp == null || level <= 0) continue;

      levels.add(
        FamilyLevelConfig(
          level: level,
          requiredTotalExp: requiredExp,
          tier: _readTier(rawLevel['tier'], fallbackLevel: level),
          maxMembers: _readInt(rawLevel['max_members']) ?? _defaultMaxMembersForLevel(level),
          adminCapacity: _readInt(rawLevel['admin_capacity']) ?? _defaultAdminCapacityForLevel(level),
          minimumVipLabel: rawLevel['minimum_vip_label']?.toString(),
          rewardIds: _readStringList(rawLevel['reward_ids']),
        ),
      );
    }

    levels.sort((a, b) => a.level.compareTo(b.level));
    return levels;
  }

  static FamilyExpRulesConfig? _parseExpRules(Object? rawRules) {
    if (rawRules is! Map) return null;

    return FamilyExpRulesConfig(
      timeExpPerBlock: _readInt(rawRules['time_exp_per_block']) ?? FamilyLevelEngine.defaultProgramConfig.expRules.timeExpPerBlock,
      timeMinutesPerBlock: _readInt(rawRules['time_minutes_per_block']) ?? FamilyLevelEngine.defaultProgramConfig.expRules.timeMinutesPerBlock,
      maxDailyTimeExp: _readInt(rawRules['max_daily_time_exp']) ?? FamilyLevelEngine.defaultProgramConfig.expRules.maxDailyTimeExp,
      coinsPerGiftExpBlock: _readInt(rawRules['coins_per_gift_exp_block']) ?? FamilyLevelEngine.defaultProgramConfig.expRules.coinsPerGiftExpBlock,
      giftExpPerCoinBlock: _readInt(rawRules['gift_exp_per_coin_block']) ?? FamilyLevelEngine.defaultProgramConfig.expRules.giftExpPerCoinBlock,
    );
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList();
  }

  static FamilyTier _readTier(Object? value, {required int fallbackLevel}) {
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'bronze') return FamilyTier.bronze;
    if (normalized == 'silver') return FamilyTier.silver;
    if (normalized == 'gold') return FamilyTier.gold;
    if (normalized == 'platinum') return FamilyTier.platinum;
    return _defaultTierForLevel(fallbackLevel);
  }
}

class FamilyLevelProgress {
  const FamilyLevelProgress({
    required this.level,
    required this.tier,
    required this.totalExp,
    required this.currentLevelStartExp,
    required this.nextLevelExp,
    required this.maxMembers,
    required this.adminCapacity,
    this.minimumVipLabel,
    this.rewardIds = const [],
  });

  final int level;
  final FamilyTier tier;
  final int totalExp;
  final int currentLevelStartExp;
  final int nextLevelExp;
  final int maxMembers;
  final int adminCapacity;
  final String? minimumVipLabel;
  final List<String> rewardIds;

  int get expIntoLevel => (totalExp - currentLevelStartExp).clamp(0, expNeededForNextLevel).toInt();
  int get expNeededForNextLevel => (nextLevelExp - currentLevelStartExp).clamp(1, 1 << 31).toInt();
  double get progress => (expIntoLevel / expNeededForNextLevel).clamp(0.0, 1.0).toDouble();
}

class FamilyExpBreakdown {
  const FamilyExpBreakdown({
    required this.quarterCarryExp,
    required this.giftCoinsSpent,
    required this.giftExp,
    required this.timeMinutes,
    required this.timeExp,
    required this.rules,
  });

  final int quarterCarryExp;
  final int giftCoinsSpent;
  final int giftExp;
  final int timeMinutes;
  final int timeExp;
  final FamilyExpRulesConfig rules;

  int get totalExp => quarterCarryExp + giftExp + timeExp;
}

class FamilyLevelEngine {
  const FamilyLevelEngine({this.config = defaultProgramConfig});

  final FamilyProgramConfig config;

  static const FamilyProgramConfig defaultProgramConfig = FamilyProgramConfig(
    levels: _defaultLevels,
    expRules: FamilyExpRulesConfig(
      timeExpPerBlock: 20,
      timeMinutesPerBlock: 5,
      maxDailyTimeExp: 800,
      coinsPerGiftExpBlock: 20,
      giftExpPerCoinBlock: 2,
    ),
  );

  // Future backend mapping:
  // GET /family/program-config
  // GET /family/me
  //
  // IMPORTANT:
  // Family level thresholds, required EXP, member capacity, admin capacity,
  // minimum VIP requirements, reward unlocks, and EXP conversion rules must come
  // from backend config rows. Flutter should only render the received config.
  // This lets Super Owner/Owner operations change family progression without a
  // Play Store update.
  //
  // Expected config shape:
  // {
  //   "levels": [
  //     {
  //       "level": 1,
  //       "required_total_exp": 0,
  //       "tier": "bronze",
  //       "max_members": 50,
  //       "admin_capacity": 2,
  //       "minimum_vip_label": "VIP 1",
  //       "reward_ids": []
  //     }
  //   ],
  //   "exp_rules": {
  //     "coins_per_gift_exp_block": 20,
  //     "gift_exp_per_coin_block": 2,
  //     "time_minutes_per_block": 5,
  //     "time_exp_per_block": 20,
  //     "max_daily_time_exp": 800
  //   }
  // }

  FamilyExpBreakdown buildBreakdown({
    required int quarterCarryExp,
    required int giftCoinsSpent,
    required int familyTimeMinutesToday,
  }) {
    return FamilyExpBreakdown(
      quarterCarryExp: quarterCarryExp,
      giftCoinsSpent: giftCoinsSpent,
      giftExp: sentGiftExpForCoins(giftCoinsSpent),
      timeMinutes: familyTimeMinutesToday,
      timeExp: timeSpentExpForMinutes(familyTimeMinutesToday),
      rules: config.expRules,
    );
  }

  int sentGiftExpForCoins(int coins) {
    final blockCoins = config.expRules.coinsPerGiftExpBlock;
    if (blockCoins <= 0) return 0;
    return (coins ~/ blockCoins) * config.expRules.giftExpPerCoinBlock;
  }

  int timeSpentExpForMinutes(int minutes) {
    final blockMinutes = config.expRules.timeMinutesPerBlock;
    if (blockMinutes <= 0) return 0;
    final rawExp = (minutes ~/ blockMinutes) * config.expRules.timeExpPerBlock;
    return rawExp.clamp(0, config.expRules.maxDailyTimeExp).toInt();
  }

  FamilyLevelProgress progressForExp(int totalExp) {
    final levels = [...config.levels]..sort((a, b) => a.level.compareTo(b.level));
    final safeLevels = levels.isEmpty ? _defaultLevels : levels;

    var current = safeLevels.first;
    for (final level in safeLevels) {
      if (totalExp >= level.requiredTotalExp) current = level;
    }

    final currentIndex = safeLevels.indexWhere((level) => level.level == current.level);
    final hasNext = currentIndex >= 0 && currentIndex < safeLevels.length - 1;
    final next = hasNext ? safeLevels[currentIndex + 1] : current;

    return FamilyLevelProgress(
      level: current.level,
      tier: current.tier,
      totalExp: totalExp,
      currentLevelStartExp: current.requiredTotalExp,
      nextLevelExp: hasNext ? next.requiredTotalExp : current.requiredTotalExp + 1,
      maxMembers: current.maxMembers,
      adminCapacity: current.adminCapacity,
      minimumVipLabel: current.minimumVipLabel,
      rewardIds: current.rewardIds,
    );
  }

  int expRequiredForLevel(int level) {
    return _configForLevel(level).requiredTotalExp;
  }

  int expNeededToAdvanceFrom(int level) {
    final current = _configForLevel(level);
    final next = _configForLevel(level + 1);
    return (next.requiredTotalExp - current.requiredTotalExp).clamp(1, 1 << 31).toInt();
  }

  FamilyTier tierForLevel(int level) {
    return _configForLevel(level).tier;
  }

  int adminCapacityForLevel(int level) {
    return _configForLevel(level).adminCapacity;
  }

  int maxMembersForLevel(int level) {
    return _configForLevel(level).maxMembers;
  }

  FamilyLevelConfig _configForLevel(int level) {
    final levels = [...config.levels]..sort((a, b) => a.level.compareTo(b.level));
    if (levels.isEmpty) return _defaultLevels.first;

    return levels.lastWhere(
      (item) => item.level <= level,
      orElse: () => levels.first,
    );
  }
}

const List<FamilyLevelConfig> _defaultLevels = [
  FamilyLevelConfig(level: 1, requiredTotalExp: 0, tier: FamilyTier.bronze, maxMembers: 50, adminCapacity: 2, minimumVipLabel: 'VIP 1'),
  FamilyLevelConfig(level: 2, requiredTotalExp: 3400, tier: FamilyTier.bronze, maxMembers: 55, adminCapacity: 2),
  FamilyLevelConfig(level: 3, requiredTotalExp: 7700, tier: FamilyTier.bronze, maxMembers: 60, adminCapacity: 2),
  FamilyLevelConfig(level: 4, requiredTotalExp: 12900, tier: FamilyTier.bronze, maxMembers: 65, adminCapacity: 2),
  FamilyLevelConfig(level: 5, requiredTotalExp: 19000, tier: FamilyTier.bronze, maxMembers: 70, adminCapacity: 2),
  FamilyLevelConfig(level: 6, requiredTotalExp: 26000, tier: FamilyTier.bronze, maxMembers: 80, adminCapacity: 2),
  FamilyLevelConfig(level: 7, requiredTotalExp: 33900, tier: FamilyTier.bronze, maxMembers: 90, adminCapacity: 2),
  FamilyLevelConfig(level: 8, requiredTotalExp: 42700, tier: FamilyTier.bronze, maxMembers: 100, adminCapacity: 2),
  FamilyLevelConfig(level: 9, requiredTotalExp: 52400, tier: FamilyTier.bronze, maxMembers: 110, adminCapacity: 2),
  FamilyLevelConfig(level: 10, requiredTotalExp: 63000, tier: FamilyTier.bronze, maxMembers: 120, adminCapacity: 3, rewardIds: ['family_badge_bronze_elite']),
  FamilyLevelConfig(level: 11, requiredTotalExp: 85200, tier: FamilyTier.silver, maxMembers: 125, adminCapacity: 3),
  FamilyLevelConfig(level: 12, requiredTotalExp: 111600, tier: FamilyTier.silver, maxMembers: 130, adminCapacity: 3),
  FamilyLevelConfig(level: 13, requiredTotalExp: 142200, tier: FamilyTier.silver, maxMembers: 135, adminCapacity: 3),
  FamilyLevelConfig(level: 14, requiredTotalExp: 177000, tier: FamilyTier.silver, maxMembers: 140, adminCapacity: 3),
  FamilyLevelConfig(level: 15, requiredTotalExp: 216000, tier: FamilyTier.silver, maxMembers: 145, adminCapacity: 3),
  FamilyLevelConfig(level: 16, requiredTotalExp: 259200, tier: FamilyTier.silver, maxMembers: 150, adminCapacity: 3),
  FamilyLevelConfig(level: 17, requiredTotalExp: 306600, tier: FamilyTier.silver, maxMembers: 155, adminCapacity: 3),
  FamilyLevelConfig(level: 18, requiredTotalExp: 358200, tier: FamilyTier.silver, maxMembers: 160, adminCapacity: 3),
  FamilyLevelConfig(level: 19, requiredTotalExp: 414000, tier: FamilyTier.silver, maxMembers: 165, adminCapacity: 3),
  FamilyLevelConfig(level: 20, requiredTotalExp: 474000, tier: FamilyTier.silver, maxMembers: 170, adminCapacity: 4, rewardIds: ['family_room_background']),
  FamilyLevelConfig(level: 21, requiredTotalExp: 559000, tier: FamilyTier.gold, maxMembers: 175, adminCapacity: 4),
  FamilyLevelConfig(level: 22, requiredTotalExp: 659000, tier: FamilyTier.gold, maxMembers: 180, adminCapacity: 4),
  FamilyLevelConfig(level: 23, requiredTotalExp: 774000, tier: FamilyTier.gold, maxMembers: 185, adminCapacity: 4),
  FamilyLevelConfig(level: 24, requiredTotalExp: 904000, tier: FamilyTier.gold, maxMembers: 190, adminCapacity: 4),
  FamilyLevelConfig(level: 25, requiredTotalExp: 1049000, tier: FamilyTier.gold, maxMembers: 195, adminCapacity: 4),
  FamilyLevelConfig(level: 26, requiredTotalExp: 1209000, tier: FamilyTier.gold, maxMembers: 200, adminCapacity: 4),
  FamilyLevelConfig(level: 27, requiredTotalExp: 1384000, tier: FamilyTier.gold, maxMembers: 205, adminCapacity: 4),
  FamilyLevelConfig(level: 28, requiredTotalExp: 1574000, tier: FamilyTier.gold, maxMembers: 210, adminCapacity: 4),
  FamilyLevelConfig(level: 29, requiredTotalExp: 1779000, tier: FamilyTier.gold, maxMembers: 215, adminCapacity: 4),
  FamilyLevelConfig(level: 30, requiredTotalExp: 1999000, tier: FamilyTier.gold, maxMembers: 220, adminCapacity: 5, rewardIds: ['family_gold_frame']),
  FamilyLevelConfig(level: 31, requiredTotalExp: 2221000, tier: FamilyTier.platinum, maxMembers: 225, adminCapacity: 5),
  FamilyLevelConfig(level: 32, requiredTotalExp: 2485000, tier: FamilyTier.platinum, maxMembers: 230, adminCapacity: 5),
  FamilyLevelConfig(level: 33, requiredTotalExp: 2791000, tier: FamilyTier.platinum, maxMembers: 235, adminCapacity: 5),
  FamilyLevelConfig(level: 34, requiredTotalExp: 3139000, tier: FamilyTier.platinum, maxMembers: 240, adminCapacity: 5),
  FamilyLevelConfig(level: 35, requiredTotalExp: 3529000, tier: FamilyTier.platinum, maxMembers: 245, adminCapacity: 5),
  FamilyLevelConfig(level: 36, requiredTotalExp: 3961000, tier: FamilyTier.platinum, maxMembers: 250, adminCapacity: 5),
  FamilyLevelConfig(level: 37, requiredTotalExp: 4435000, tier: FamilyTier.platinum, maxMembers: 260, adminCapacity: 5),
  FamilyLevelConfig(level: 38, requiredTotalExp: 4951000, tier: FamilyTier.platinum, maxMembers: 270, adminCapacity: 5),
  FamilyLevelConfig(level: 39, requiredTotalExp: 5509000, tier: FamilyTier.platinum, maxMembers: 280, adminCapacity: 5),
  FamilyLevelConfig(level: 40, requiredTotalExp: 6109000, tier: FamilyTier.platinum, maxMembers: 300, adminCapacity: 6, rewardIds: ['family_royal_identity']),
];

FamilyTier _defaultTierForLevel(int level) {
  if (level >= 31) return FamilyTier.platinum;
  if (level >= 21) return FamilyTier.gold;
  if (level >= 11) return FamilyTier.silver;
  return FamilyTier.bronze;
}

int _defaultAdminCapacityForLevel(int level) {
  if (level >= 40) return 6;
  if (level >= 30) return 5;
  if (level >= 20) return 4;
  if (level >= 10) return 3;
  return 2;
}

int _defaultMaxMembersForLevel(int level) {
  if (level >= 40) return 300;
  if (level >= 30) return 220;
  if (level >= 20) return 170;
  if (level >= 10) return 120;
  return 50 + ((level - 1).clamp(0, 8).toInt() * 5);
}

String compactFamilyExp(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  return value.toString();
}
