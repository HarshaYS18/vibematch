import 'package:flutter/material.dart';

enum VipProgressDifficulty {
  easy,
  medium,
  hard,
  veryHard,
  insane,
}

extension VipProgressDifficultyLabel on VipProgressDifficulty {
  String get label {
    switch (this) {
      case VipProgressDifficulty.easy:
        return 'Easy';
      case VipProgressDifficulty.medium:
        return 'Medium';
      case VipProgressDifficulty.hard:
        return 'Hard';
      case VipProgressDifficulty.veryHard:
        return 'Very hard';
      case VipProgressDifficulty.insane:
        return 'Insane';
    }
  }

  Color get color {
    switch (this) {
      case VipProgressDifficulty.easy:
        return const Color(0xFF12C7B7);
      case VipProgressDifficulty.medium:
        return const Color(0xFF6D5DF6);
      case VipProgressDifficulty.hard:
        return const Color(0xFFE84C72);
      case VipProgressDifficulty.veryHard:
        return const Color(0xFFC99A3B);
      case VipProgressDifficulty.insane:
        return const Color(0xFF251538);
    }
  }
}

class VipRewardConfig {
  const VipRewardConfig({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.unlockVipLevel,
    this.unlockSvipLevel,
    this.enabled = true,
    this.isProtection = false,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int? unlockVipLevel;
  final int? unlockSvipLevel;
  final bool enabled;
  final bool isProtection;
}

class VipLevelConfig {
  const VipLevelConfig({
    required this.level,
    required this.requiredRechargeCoins,
    required this.difficulty,
    this.rewardIds = const [],
  });

  final int level;
  final int requiredRechargeCoins;
  final VipProgressDifficulty difficulty;
  final List<String> rewardIds;
}

class SvipLevelConfig {
  const SvipLevelConfig({
    required this.level,
    required this.monthlyRechargeCoins,
    required this.rewardId,
  });

  final int level;
  final int monthlyRechargeCoins;
  final String rewardId;
}

class VipProgramSnapshot {
  const VipProgramSnapshot({
    required this.vipLevel,
    required this.svipLevel,
    required this.lifetimeRechargeCoins,
    required this.monthlyRechargeCoins,
    required this.vipLevels,
    required this.svipLevels,
    required this.vipRewards,
    required this.svipRewards,
  });

  final int vipLevel;
  final int svipLevel;
  final int lifetimeRechargeCoins;
  final int monthlyRechargeCoins;
  final List<VipLevelConfig> vipLevels;
  final List<SvipLevelConfig> svipLevels;
  final List<VipRewardConfig> vipRewards;
  final List<VipRewardConfig> svipRewards;

  VipLevelConfig get currentVipLevel {
    if (vipLevel <= 0) {
      return const VipLevelConfig(
        level: 0,
        requiredRechargeCoins: 0,
        difficulty: VipProgressDifficulty.easy,
      );
    }
    return vipLevels.lastWhere(
      (level) => level.level <= vipLevel,
      orElse: () => vipLevels.first,
    );
  }

  VipLevelConfig get nextVipLevel {
    return vipLevels.firstWhere(
      (level) => level.level > vipLevel,
      orElse: () => vipLevels.last,
    );
  }

  SvipLevelConfig get nextSvipLevel {
    return svipLevels.firstWhere(
      (level) => level.level > svipLevel,
      orElse: () => svipLevels.last,
    );
  }

  double get vipProgress {
    final currentRequired = currentVipLevel.requiredRechargeCoins;
    final nextRequired = nextVipLevel.requiredRechargeCoins;
    if (nextRequired <= currentRequired) return 1;

    final progress = (lifetimeRechargeCoins - currentRequired) /
        (nextRequired - currentRequired);
    return progress.clamp(0.0, 1.0);
  }

  double get svipProgress {
    final nextRequired = nextSvipLevel.monthlyRechargeCoins;
    if (nextRequired <= 0) return 1;
    return (monthlyRechargeCoins / nextRequired).clamp(0.0, 1.0);
  }

  List<VipRewardConfig> unlockedVipRewards() {
    return vipRewards.where((reward) {
      final unlockLevel = reward.unlockVipLevel ?? 0;
      return reward.enabled && unlockLevel <= vipLevel;
    }).toList();
  }

  List<VipRewardConfig> unlockedSvipRewards() {
    return svipRewards.where((reward) {
      final unlockLevel = reward.unlockSvipLevel ?? 0;
      return reward.enabled && unlockLevel <= svipLevel;
    }).toList();
  }
}
