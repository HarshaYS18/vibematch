import 'package:flutter/material.dart';

class RoomLevelRule {
  const RoomLevelRule({
    required this.title,
    required this.description,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<Color> colors;
}

class RoomLevelBand {
  const RoomLevelBand({
    required this.startLevel,
    required this.endLevel,
    required this.name,
    required this.description,
    required this.colors,
  });

  final int startLevel;
  final int endLevel;
  final String name;
  final String description;
  final List<Color> colors;

  bool contains(int level) => level >= startLevel && level <= endLevel;
}

class RoomLevelSnapshot {
  const RoomLevelSnapshot({
    required this.level,
    required this.currentLevelExp,
    required this.nextLevelRequiredExp,
    required this.totalExp,
    required this.dailyStayMinutes,
    required this.dailyStayExp,
    required this.giftCoinExp,
  });

  final int level;
  final int currentLevelExp;
  final int nextLevelRequiredExp;
  final int totalExp;
  final int dailyStayMinutes;
  final int dailyStayExp;
  final int giftCoinExp;

  double get progress {
    if (nextLevelRequiredExp <= 0) return 1;
    return (currentLevelExp / nextLevelRequiredExp).clamp(0, 1).toDouble();
  }

  int get remainingExp => (nextLevelRequiredExp - currentLevelExp).clamp(0, nextLevelRequiredExp);
}
