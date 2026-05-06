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
        FamilyTier.platinum => 'More hard',
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

class FamilyLevelProgress {
  const FamilyLevelProgress({
    required this.level,
    required this.tier,
    required this.totalExp,
    required this.currentLevelStartExp,
    required this.nextLevelExp,
  });

  final int level;
  final FamilyTier tier;
  final int totalExp;
  final int currentLevelStartExp;
  final int nextLevelExp;

  int get expIntoLevel => (totalExp - currentLevelStartExp).clamp(0, expNeededForNextLevel);
  int get expNeededForNextLevel => (nextLevelExp - currentLevelStartExp).clamp(1, 1 << 31);
  double get progress => (expIntoLevel / expNeededForNextLevel).clamp(0.0, 1.0);
}

class FamilyExpBreakdown {
  const FamilyExpBreakdown({
    required this.quarterCarryExp,
    required this.giftCoinsSpent,
    required this.giftExp,
    required this.timeMinutes,
    required this.timeExp,
  });

  final int quarterCarryExp;
  final int giftCoinsSpent;
  final int giftExp;
  final int timeMinutes;
  final int timeExp;

  int get totalExp => quarterCarryExp + giftExp + timeExp;
}

class FamilyLevelEngine {
  const FamilyLevelEngine();

  static const int timeExpPerBlock = 20;
  static const int timeMinutesPerBlock = 5;
  static const int maxDailyTimeExp = 800;
  static const int coinsPerGiftExpBlock = 20;
  static const int giftExpPerCoinBlock = 2;
  static const int maxLevel = 40;

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
    );
  }

  int sentGiftExpForCoins(int coins) => (coins ~/ coinsPerGiftExpBlock) * giftExpPerCoinBlock;

  int timeSpentExpForMinutes(int minutes) {
    final rawExp = (minutes ~/ timeMinutesPerBlock) * timeExpPerBlock;
    return rawExp.clamp(0, maxDailyTimeExp);
  }

  FamilyLevelProgress progressForExp(int totalExp) {
    var level = 1;
    var currentStart = 0;
    var next = expRequiredForLevel(2);

    while (totalExp >= next && level < maxLevel) {
      level++;
      currentStart = next;
      next += expNeededToAdvanceFrom(level);
    }

    return FamilyLevelProgress(
      level: level,
      tier: tierForLevel(level),
      totalExp: totalExp,
      currentLevelStartExp: currentStart,
      nextLevelExp: next,
    );
  }

  int expRequiredForLevel(int level) {
    if (level <= 1) return 0;
    var total = 0;
    for (var current = 1; current < level; current++) {
      total += expNeededToAdvanceFrom(current);
    }
    return total;
  }

  int expNeededToAdvanceFrom(int level) {
    final tier = tierForLevel(level);
    final tierLevel = ((level - 1) % 10) + 1;
    return switch (tier) {
      FamilyTier.bronze => 2500 + tierLevel * 900,
      FamilyTier.silver => 18000 + tierLevel * 4200,
      FamilyTier.gold => 70000 + tierLevel * 15000,
      FamilyTier.platinum => 180000 + tierLevel * 42000,
    };
  }

  FamilyTier tierForLevel(int level) {
    if (level >= 31) return FamilyTier.platinum;
    if (level >= 21) return FamilyTier.gold;
    if (level >= 11) return FamilyTier.silver;
    return FamilyTier.bronze;
  }

  int adminCapacityForLevel(int level) {
    if (level >= 30) return 5;
    if (level >= 20) return 4;
    if (level >= 10) return 3;
    return 2;
  }
}

String compactFamilyExp(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  return value.toString();
}
