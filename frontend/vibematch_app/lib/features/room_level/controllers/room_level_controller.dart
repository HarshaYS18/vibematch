import 'package:flutter/material.dart';

import '../models/room_level_models.dart';

class RoomLevelController {
  const RoomLevelController._();

  static const int maxLevel = 100;
  static const int dailyStayMinutesForReward = 30;
  static const int maxDailyStayExpPerPerson = 300;
  static const int giftCoinsPerExp = 10;

  static const List<RoomLevelRule> rules = [
    RoomLevelRule(
      title: 'Daily stay EXP',
      description: 'A user sitting in the chatroom for 30 minutes gives the room 300 EXP. Max 300 stay EXP per person per day.',
      icon: Icons.timer_rounded,
      colors: [Color(0xFF12C7B7), Color(0xFF5E6DFF)],
    ),
    RoomLevelRule(
      title: 'Gift EXP',
      description: 'Every 10 gift coins spent in the room gives 1 room EXP. Gift EXP has no daily limit.',
      icon: Icons.card_giftcard_rounded,
      colors: [Color(0xFFE84C72), Color(0xFFFFB45E)],
    ),
    RoomLevelRule(
      title: 'Level curve',
      description: 'Early levels are easy. Levels 1-50 become steadily harder. From 51 onward each level takes extreme effort, scaling insanely toward 100.',
      icon: Icons.trending_up_rounded,
      colors: [Color(0xFFC99A3B), Color(0xFF251538)],
    ),
  ];

  static const List<RoomLevelBand> bands = [
    RoomLevelBand(
      startLevel: 1,
      endLevel: 10,
      name: 'Fresh Room',
      description: 'Normal starter room glow.',
      colors: [Color(0xFF8BE7D8), Color(0xFF12C7B7)],
    ),
    RoomLevelBand(
      startLevel: 11,
      endLevel: 25,
      name: 'Active Room',
      description: 'Better activity and steady room growth.',
      colors: [Color(0xFF6D5DF6), Color(0xFF12C7B7)],
    ),
    RoomLevelBand(
      startLevel: 26,
      endLevel: 40,
      name: 'Hot Room',
      description: 'Popular room with strong audience and gift flow.',
      colors: [Color(0xFFFF7A45), Color(0xFFE84C72)],
    ),
    RoomLevelBand(
      startLevel: 41,
      endLevel: 50,
      name: 'Elite Room',
      description: 'Hard-earned premium room level range.',
      colors: [Color(0xFFC99A3B), Color(0xFF8C5CF6)],
    ),
    RoomLevelBand(
      startLevel: 51,
      endLevel: 70,
      name: 'Royal Room',
      description: 'From level 51, each level takes huge repeated effort.',
      colors: [Color(0xFFFFD166), Color(0xFFB13C77), Color(0xFF251538)],
    ),
    RoomLevelBand(
      startLevel: 71,
      endLevel: 90,
      name: 'Mythic Room',
      description: 'Insane grind range for long-running rich rooms.',
      colors: [Color(0xFF12C7B7), Color(0xFF6D5DF6), Color(0xFFE84C72)],
    ),
    RoomLevelBand(
      startLevel: 91,
      endLevel: 100,
      name: 'Legend Room',
      description: 'Highest super-rich gradient mix for legendary rooms.',
      colors: [Color(0xFFFFF1A6), Color(0xFFFF5F7E), Color(0xFF8C5CF6), Color(0xFF05020A)],
    ),
  ];

  static RoomLevelBand bandForLevel(int level) {
    return bands.firstWhere(
      (band) => band.contains(level),
      orElse: () => bands.first,
    );
  }

  static int requiredExpForNextLevel(int level) {
    if (level < 1) return 300;
    if (level < 10) return 260 + (level * 90);
    if (level < 25) return 1100 + ((level - 10) * 220);
    if (level < 50) return 4800 + ((level - 25) * 620) + ((level - 25) * (level - 25) * 18);
    if (level < 70) return 28000 + ((level - 50) * 7800) + ((level - 50) * (level - 50) * 950);
    if (level < 90) return 260000 + ((level - 70) * 42000) + ((level - 70) * (level - 70) * 6800);
    if (level < maxLevel) return 1700000 + ((level - 90) * 260000) + ((level - 90) * (level - 90) * 65000);
    return 0;
  }

  static int stayExpForMinutes(int minutes) {
    if (minutes < dailyStayMinutesForReward) return 0;
    return maxDailyStayExpPerPerson;
  }

  static int giftExpForCoins(int coins) {
    if (coins <= 0) return 0;
    return coins ~/ giftCoinsPerExp;
  }

  static RoomLevelSnapshot mockSnapshot() {
    const level = 37;
    final required = requiredExpForNextLevel(level);
    return RoomLevelSnapshot(
      level: level,
      currentLevelExp: (required * 0.62).round(),
      nextLevelRequiredExp: required,
      totalExp: 184620,
      dailyStayMinutes: 30,
      dailyStayExp: stayExpForMinutes(30),
      giftCoinExp: giftExpForCoins(48600),
    );
  }
}
