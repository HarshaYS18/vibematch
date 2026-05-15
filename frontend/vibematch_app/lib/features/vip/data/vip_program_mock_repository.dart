import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/vip_program_models.dart';

class VipProgramMockRepository {
  const VipProgramMockRepository();

  static const int _vipMaxRequiredCoins = 50000000000;
  static const int _svipMaxRequiredCoins = 2000000000;
  static const double _curveExponent = 2.35;

  VipProgramSnapshot loadSnapshot({
    int vipLevel = 25,
    int svipLevel = 3,
    int lifetimeRechargeCoins = 128500,
    int monthlyRechargeCoins = 42000,
    Map<String, dynamic>? programConfig,
  }) {
    final vipLevels = _parseVipLevels(programConfig?['vip_levels']) ?? _defaultVipLevels;
    final svipLevels = _parseSvipLevels(programConfig?['svip_levels']) ?? _defaultSvipLevels;

    return VipProgramSnapshot(
      vipLevel: vipLevel.clamp(0, 50).toInt(),
      svipLevel: svipLevel.clamp(0, 10).toInt(),
      lifetimeRechargeCoins: lifetimeRechargeCoins,
      monthlyRechargeCoins: monthlyRechargeCoins,
      vipLevels: vipLevels,
      svipLevels: svipLevels,
      vipRewards: _vipRewards,
      svipRewards: _svipRewards,
    );
  }

  // Future backend mapping:
  // GET /vip/program-config
  // GET /vip/me
  //
  // IMPORTANT:
  // VIP/SVIP required coin amounts must come from backend config rows, not from
  // Flutter formulas. Flutter should only render the received level config.
  // That lets Super Owner/Owner operations change:
  // - VIP level required_recharge_coins
  // - SVIP level monthly_recharge_coins
  // - difficulty labels
  // - reward unlock mapping
  // without publishing a new app update.
  //
  // Expected config shape:
  // {
  //   "vip_levels": [
  //     {"level": 1, "required_recharge_coins": 1000, "difficulty": "easy", "reward_ids": []}
  //   ],
  //   "svip_levels": [
  //     {"level": 1, "monthly_recharge_coins": 15000, "reward_id": "svip_1"}
  //   ]
  // }

  static final List<VipLevelConfig> _defaultVipLevels = _buildDefaultVipLevels();
  static final List<SvipLevelConfig> _defaultSvipLevels = _buildDefaultSvipLevels();

  static List<VipLevelConfig>? _parseVipLevels(Object? rawLevels) {
    if (rawLevels is! List) return null;

    final parsed = <VipLevelConfig>[];
    for (final rawLevel in rawLevels) {
      if (rawLevel is! Map) continue;

      final level = _readInt(rawLevel['level']);
      final requiredCoins = _readInt(rawLevel['required_recharge_coins']);
      if (level == null || requiredCoins == null || level <= 0) continue;

      parsed.add(
        VipLevelConfig(
          level: level,
          requiredRechargeCoins: requiredCoins,
          difficulty: _readDifficulty(rawLevel['difficulty'], fallbackLevel: level),
          rewardIds: _readStringList(rawLevel['reward_ids']),
        ),
      );
    }

    if (parsed.isEmpty) return null;
    parsed.sort((a, b) => a.level.compareTo(b.level));
    return parsed;
  }

  static List<SvipLevelConfig>? _parseSvipLevels(Object? rawLevels) {
    if (rawLevels is! List) return null;

    final parsed = <SvipLevelConfig>[];
    for (final rawLevel in rawLevels) {
      if (rawLevel is! Map) continue;

      final level = _readInt(rawLevel['level']);
      final monthlyCoins = _readInt(rawLevel['monthly_recharge_coins']);
      if (level == null || monthlyCoins == null || level <= 0) continue;

      parsed.add(
        SvipLevelConfig(
          level: level,
          monthlyRechargeCoins: monthlyCoins,
          rewardId: (rawLevel['reward_id'] ?? 'svip_$level').toString(),
        ),
      );
    }

    if (parsed.isEmpty) return null;
    parsed.sort((a, b) => a.level.compareTo(b.level));
    return parsed;
  }

  static List<VipLevelConfig> _buildDefaultVipLevels() {
    return List.generate(50, (index) {
      final level = index + 1;
      final rewards = <String>[
        if (level == 20) 'vip_background_20',
        if (level == 35) 'vip_mute_protection',
        if (level == 40) 'vip_background_40',
        if (level == 40) 'vip_kick_protection',
      ];

      return VipLevelConfig(
        level: level,
        requiredRechargeCoins: _defaultVipRequiredCoins(level),
        difficulty: _defaultVipDifficulty(level),
        rewardIds: rewards,
      );
    });
  }

  static List<SvipLevelConfig> _buildDefaultSvipLevels() {
    return List.generate(10, (index) {
      final level = index + 1;
      return SvipLevelConfig(
        level: level,
        monthlyRechargeCoins: _defaultSvipRequiredCoins(level),
        rewardId: 'svip_$level',
      );
    });
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

  static VipProgressDifficulty _readDifficulty(Object? value, {required int fallbackLevel}) {
    final normalized = value?.toString().trim().toLowerCase().replaceAll('_', '');
    if (normalized == 'easy') return VipProgressDifficulty.easy;
    if (normalized == 'medium') return VipProgressDifficulty.medium;
    if (normalized == 'hard') return VipProgressDifficulty.hard;
    if (normalized == 'veryhard') return VipProgressDifficulty.veryHard;
    if (normalized == 'insane') return VipProgressDifficulty.insane;
    return _defaultVipDifficulty(fallbackLevel);
  }

  static const List<VipRewardConfig> _vipRewards = [
    VipRewardConfig(
      id: 'vip_background_20',
      title: 'VIP Lounge Background',
      description: 'Unlock a premium VIP room background style at VIP 20.',
      icon: Icons.wallpaper_rounded,
      unlockVipLevel: 20,
    ),
    VipRewardConfig(
      id: 'vip_mute_protection',
      title: 'Priority Voice Protection',
      description: 'Eligible VIP 35 users receive enhanced protection from room mute actions, subject to official safety rules.',
      icon: Icons.mic_external_on_rounded,
      unlockVipLevel: 35,
      isProtection: true,
    ),
    VipRewardConfig(
      id: 'vip_background_40',
      title: 'Royal VIP Background',
      description: 'Unlock the high-tier VIP 40 background collection for rooms and profile display zones.',
      icon: Icons.diamond_rounded,
      unlockVipLevel: 40,
    ),
    VipRewardConfig(
      id: 'vip_kick_protection',
      title: 'Priority Room Stay Protection',
      description: 'Eligible VIP 40 users receive enhanced protection from room kickout actions, subject to official safety rules.',
      icon: Icons.security_rounded,
      unlockVipLevel: 40,
      isProtection: true,
    ),
  ];

  static const List<VipRewardConfig> _svipRewards = [
    VipRewardConfig(
      id: 'svip_1',
      title: 'Room Message Recall',
      description: 'Recall eligible messages you sent in chatrooms within the allowed time window.',
      icon: Icons.undo_rounded,
      unlockSvipLevel: 1,
    ),
    VipRewardConfig(
      id: 'svip_2',
      title: 'Private Ranking Identity',
      description: 'Hide your public identity in eligible room contribution rankings while preserving backend audit visibility.',
      icon: Icons.visibility_off_rounded,
      unlockSvipLevel: 2,
    ),
    VipRewardConfig(
      id: 'svip_3',
      title: 'Monthly Entrance Effect',
      description: 'Equip a premium SVIP entrance visual and sound effect when entering rooms.',
      icon: Icons.auto_awesome_rounded,
      unlockSvipLevel: 3,
    ),
    VipRewardConfig(
      id: 'svip_4',
      title: 'Kickout Protection',
      description: 'Receive enhanced protection from room kickout actions, subject to official moderation and safety rules.',
      icon: Icons.shield_rounded,
      unlockSvipLevel: 4,
      isProtection: true,
    ),
    VipRewardConfig(
      id: 'svip_5',
      title: 'Exclusive Avatar Frame',
      description: 'Unlock a premium SVIP avatar frame while your monthly status remains active.',
      icon: Icons.account_circle_rounded,
      unlockSvipLevel: 5,
    ),
    VipRewardConfig(
      id: 'svip_6',
      title: 'Personalized Gift Style',
      description: 'Access a custom gift styling slot for approved premium gift visuals.',
      icon: Icons.card_giftcard_rounded,
      unlockSvipLevel: 6,
    ),
    VipRewardConfig(
      id: 'svip_7',
      title: 'Discreet Room List Display',
      description: 'Show a discreet hidden-name state in eligible chatroom lists without granting official hidden-presence powers.',
      icon: Icons.person_off_rounded,
      unlockSvipLevel: 7,
    ),
    VipRewardConfig(
      id: 'svip_8',
      title: 'Premium Numeric ID',
      description: 'Unlock access to a premium custom numeric ID option when available.',
      icon: Icons.pin_rounded,
      unlockSvipLevel: 8,
    ),
    VipRewardConfig(
      id: 'svip_9',
      title: 'Priority Support Lane',
      description: 'Receive priority customer support routing for account and payment issues.',
      icon: Icons.support_agent_rounded,
      unlockSvipLevel: 9,
    ),
    VipRewardConfig(
      id: 'svip_10',
      title: 'Custom Text ID',
      description: 'Unlock the highest-tier text custom ID privilege, subject to reserved-name and official-handle rules.',
      icon: Icons.badge_rounded,
      unlockSvipLevel: 10,
    ),
  ];

  static VipProgressDifficulty _defaultVipDifficulty(int level) {
    if (level <= 10) return VipProgressDifficulty.easy;
    if (level <= 20) return VipProgressDifficulty.medium;
    if (level <= 30) return VipProgressDifficulty.hard;
    if (level <= 40) return VipProgressDifficulty.veryHard;
    return VipProgressDifficulty.insane;
  }

  static int _defaultVipRequiredCoins(int level) {
    if (level <= 0) return 0;
    if (level == 1) return 1;
    if (level >= 50) return _vipMaxRequiredCoins;
    return _curvedRequiredCoins(
      level: level,
      maxLevel: 50,
      maxRequiredCoins: _vipMaxRequiredCoins,
    );
  }

  static int _defaultSvipRequiredCoins(int level) {
    if (level <= 0) return 0;
    if (level == 1) return 1;
    if (level >= 10) return _svipMaxRequiredCoins;
    return _curvedRequiredCoins(
      level: level,
      maxLevel: 10,
      maxRequiredCoins: _svipMaxRequiredCoins,
    );
  }

  static int _curvedRequiredCoins({
    required int level,
    required int maxLevel,
    required int maxRequiredCoins,
  }) {
    if (level <= 1) return 0;
    final ratio = (level - 1) / (maxLevel - 1);
    return (maxRequiredCoins * math.pow(ratio, _curveExponent)).round();
  }
}
