import 'package:flutter/material.dart';

import '../models/vip_program_models.dart';

class VipProgramMockRepository {
  const VipProgramMockRepository();

  VipProgramSnapshot loadSnapshot({
    int vipLevel = 25,
    int svipLevel = 3,
    int lifetimeRechargeCoins = 128500,
    int monthlyRechargeCoins = 42000,
  }) {
    return VipProgramSnapshot(
      vipLevel: vipLevel.clamp(0, 50),
      svipLevel: svipLevel.clamp(0, 10),
      lifetimeRechargeCoins: lifetimeRechargeCoins,
      monthlyRechargeCoins: monthlyRechargeCoins,
      vipLevels: _vipLevels,
      svipLevels: _svipLevels,
      vipRewards: _vipRewards,
      svipRewards: _svipRewards,
    );
  }

  // Later backend mapping:
  // GET /vip/program-config
  // GET /vip/me
  // The app renders whatever rewards/config are returned, so privileges can be
  // enabled, disabled, renamed, reordered, or moved to another level without an
  // app release.
  static final List<VipLevelConfig> _vipLevels = List.generate(50, (index) {
    final level = index + 1;
    final difficulty = _vipDifficulty(level);
    final requiredCoins = _vipRequiredCoins(level);
    final rewards = <String>[
      if (level == 20) 'vip_background_20',
      if (level == 35) 'vip_mute_protection',
      if (level == 40) 'vip_background_40',
      if (level == 40) 'vip_kick_protection',
    ];

    return VipLevelConfig(
      level: level,
      requiredRechargeCoins: requiredCoins,
      difficulty: difficulty,
      rewardIds: rewards,
    );
  });

  static final List<SvipLevelConfig> _svipLevels = List.generate(10, (index) {
    final level = index + 1;
    return SvipLevelConfig(
      level: level,
      monthlyRechargeCoins: _svipRequiredCoins(level),
      rewardId: 'svip_$level',
    );
  });

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

  static VipProgressDifficulty _vipDifficulty(int level) {
    if (level <= 10) return VipProgressDifficulty.easy;
    if (level <= 20) return VipProgressDifficulty.medium;
    if (level <= 30) return VipProgressDifficulty.hard;
    if (level <= 40) return VipProgressDifficulty.veryHard;
    return VipProgressDifficulty.insane;
  }

  static int _vipRequiredCoins(int level) {
    if (level <= 0) return 0;
    if (level <= 10) return level * 1000;
    if (level <= 20) return 10000 + ((level - 10) * 3500);
    if (level <= 30) return 45000 + ((level - 20) * 9000);
    if (level <= 40) return 135000 + ((level - 30) * 22000);
    return 355000 + ((level - 40) * 58000);
  }

  static int _svipRequiredCoins(int level) {
    if (level <= 0) return 0;
    if (level <= 3) return level * 15000;
    if (level <= 6) return 45000 + ((level - 3) * 35000);
    if (level <= 8) return 150000 + ((level - 6) * 70000);
    return 290000 + ((level - 8) * 150000);
  }
}
