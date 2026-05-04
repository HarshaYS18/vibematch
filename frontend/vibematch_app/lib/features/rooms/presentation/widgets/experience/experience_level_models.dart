import 'package:flutter/material.dart';

import '../room_theme.dart';

enum ExperienceLevelType {
  sent,
  received;

  String get title => switch (this) {
        ExperienceLevelType.sent => 'Sent EXP',
        ExperienceLevelType.received => 'Received EXP',
      };

  String get shortLabel => switch (this) {
        ExperienceLevelType.sent => 'Sent',
        ExperienceLevelType.received => 'Received',
      };

  String get backendValue => switch (this) {
        ExperienceLevelType.sent => 'sent',
        ExperienceLevelType.received => 'received',
      };

  IconData get baseIcon => switch (this) {
        ExperienceLevelType.sent => Icons.north_east_rounded,
        ExperienceLevelType.received => Icons.favorite_rounded,
      };

  List<Color> get baseGradient => switch (this) {
        ExperienceLevelType.sent => const [Color(0xFF0F6BFF), Color(0xFF12C7B7), Color(0xFF7A5CFF)],
        ExperienceLevelType.received => const [Color(0xFFFF4F93), Color(0xFFFF8FB3), Color(0xFF8C5CF6)],
      };
}

enum ExperienceTier {
  starter,
  rising,
  premium,
  elite,
  royal,
  sovereign,
  mythic,
  immortal;

  String get label => switch (this) {
        ExperienceTier.starter => 'Starter',
        ExperienceTier.rising => 'Rising',
        ExperienceTier.premium => 'Premium',
        ExperienceTier.elite => 'Elite',
        ExperienceTier.royal => 'Royal',
        ExperienceTier.sovereign => 'Sovereign',
        ExperienceTier.mythic => 'Mythic',
        ExperienceTier.immortal => 'Immortal',
      };
}

class ExperienceLevelProgress {
  const ExperienceLevelProgress({
    required this.level,
    required this.totalExp,
    required this.currentLevelStartExp,
    required this.nextLevelExp,
    required this.progress,
    required this.tier,
  });

  final int level;
  final int totalExp;
  final int currentLevelStartExp;
  final int nextLevelExp;
  final double progress;
  final ExperienceTier tier;

  int get expIntoLevel => (totalExp - currentLevelStartExp).clamp(0, expNeededForNextLevel);
  int get expNeededForNextLevel => (nextLevelExp - currentLevelStartExp).clamp(0, 1 << 31);
  bool get isMaxLevel => level >= 200;
}

class ExperiencePillStyle {
  const ExperiencePillStyle({
    required this.gradient,
    required this.crownIcon,
    required this.crownColor,
    required this.glowColor,
    required this.textColor,
    required this.tier,
  });

  final List<Color> gradient;
  final IconData crownIcon;
  final Color crownColor;
  final Color glowColor;
  final Color textColor;
  final ExperienceTier tier;
}

ExperienceTier experienceTierForLevel(int level) {
  if (level >= 175) return ExperienceTier.immortal;
  if (level >= 150) return ExperienceTier.mythic;
  if (level >= 125) return ExperienceTier.sovereign;
  if (level >= 100) return ExperienceTier.royal;
  if (level >= 75) return ExperienceTier.elite;
  if (level >= 50) return ExperienceTier.premium;
  if (level >= 25) return ExperienceTier.rising;
  return ExperienceTier.starter;
}

int experienceBandForLevel(int level) {
  final safeLevel = level.clamp(1, 200);
  return ((safeLevel - 1) ~/ 20).clamp(0, 9);
}

IconData experienceCrownForBand(int band) {
  return switch (band) {
    0 => Icons.workspace_premium_rounded,
    1 => Icons.emoji_events_rounded,
    2 => Icons.military_tech_rounded,
    3 => Icons.shield_rounded,
    4 => Icons.diamond_rounded,
    5 => Icons.local_fire_department_rounded,
    6 => Icons.auto_awesome_rounded,
    7 => Icons.stars_rounded,
    8 => Icons.flare_rounded,
    _ => Icons.brightness_7_rounded,
  };
}

ExperiencePillStyle experiencePillStyleFor({
  required ExperienceLevelType type,
  required int level,
}) {
  final tier = experienceTierForLevel(level);
  final band = experienceBandForLevel(level);
  final crownIcon = experienceCrownForBand(band);
  final textColor = Colors.white;

  if (type == ExperienceLevelType.sent) {
    final sentGradients = <List<Color>>[
      const [Color(0xFF2F80FF), Color(0xFF12C7B7), Color(0xFF5ED7FF)],
      const [Color(0xFF155EEF), Color(0xFF0EA5E9), Color(0xFF12C7B7)],
      const [Color(0xFF154DFF), Color(0xFF12C7B7), Color(0xFF7A5CFF)],
      const [Color(0xFF0B4BD3), Color(0xFF0EA5E9), Color(0xFF7C3AED)],
      const [Color(0xFF0B2D89), Color(0xFF38BDF8), Color(0xFF8C5CF6)],
      const [Color(0xFF0B1E7A), Color(0xFF0EA5E9), RoomColors.gold],
      const [Color(0xFF061A4A), Color(0xFF111827), Color(0xFF38BDF8), Color(0xFFC084FC)],
      const [Color(0xFF06102E), Color(0xFF111827), Color(0xFF0EA5E9), Color(0xFFFFD166)],
      const [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF38BDF8), Color(0xFFE0F2FE), Color(0xFFFFD166)],
      const [Color(0xFF020617), Color(0xFF08111F), Color(0xFF67E8F9), Color(0xFFFFFFFF), Color(0xFFFFD166)],
    ];
    final crownColors = const [
      Color(0xFFD9F4FF),
      Color(0xFFE5F8FF),
      Color(0xFFE5F2FF),
      Color(0xFFE0E7FF),
      Color(0xFFDDEBFF),
      Color(0xFFFFE9A6),
      Color(0xFFFFECB3),
      Color(0xFFFFF1B8),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
    ];
    final glowColors = const [
      Color(0xFF12C7B7),
      Color(0xFF0EA5E9),
      Color(0xFF2CCBFF),
      Color(0xFF60A5FA),
      Color(0xFF8C5CF6),
      RoomColors.gold,
      Color(0xFFC084FC),
      Color(0xFFFFD166),
      Color(0xFFE0F2FE),
      Color(0xFFFFFFFF),
    ];

    return ExperiencePillStyle(
      gradient: sentGradients[band],
      crownIcon: crownIcon,
      crownColor: crownColors[band],
      glowColor: glowColors[band],
      textColor: textColor,
      tier: tier,
    );
  }

  final receivedGradients = <List<Color>>[
    const [Color(0xFFFF4F93), Color(0xFFFF8FB3), Color(0xFFFFB4CF)],
    const [Color(0xFFF43F7F), Color(0xFFFF8FB3), Color(0xFFFB7185)],
    const [Color(0xFFE84C72), Color(0xFFFF8FB3), Color(0xFF8C5CF6)],
    const [Color(0xFFBE185D), Color(0xFFFF4F93), Color(0xFF7C3AED)],
    const [Color(0xFF9D174D), Color(0xFFFF4F93), Color(0xFFA855F7)],
    const [Color(0xFF881337), Color(0xFFE84C72), RoomColors.gold],
    const [Color(0xFF4A061D), Color(0xFF111827), Color(0xFFFF4F93), Color(0xFFC084FC)],
    const [Color(0xFF2A0617), Color(0xFF111827), Color(0xFFFF4F93), Color(0xFFFFD166)],
    const [Color(0xFF020617), Color(0xFF4A061D), Color(0xFFFF4F93), Color(0xFFFCE7F3), Color(0xFFFFD166)],
    const [Color(0xFF020617), Color(0xFF3B071C), Color(0xFFFF8FB3), Color(0xFFFFFFFF), Color(0xFFFFD166)],
  ];
  final crownColors = const [
    Color(0xFFFFECF5),
    Color(0xFFFFF0F7),
    Color(0xFFFFF0F7),
    Color(0xFFFCE7F3),
    Color(0xFFFFD7EA),
    Color(0xFFFFE9A6),
    Color(0xFFFFECB3),
    Color(0xFFFFF1B8),
    Color(0xFFFFFFFF),
    Color(0xFFFFFFFF),
  ];
  final glowColors = const [
    Color(0xFFFF6FA7),
    Color(0xFFFF6FA7),
    Color(0xFFFF6FA7),
    Color(0xFFF472B6),
    Color(0xFFA855F7),
    RoomColors.gold,
    Color(0xFFC084FC),
    Color(0xFFFFD166),
    Color(0xFFFCE7F3),
    Color(0xFFFFFFFF),
  ];

  return ExperiencePillStyle(
    gradient: receivedGradients[band],
    crownIcon: crownIcon,
    crownColor: crownColors[band],
    glowColor: glowColors[band],
    textColor: textColor,
    tier: tier,
  );
}
