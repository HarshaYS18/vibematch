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

IconData experienceCrownForTier(ExperienceTier tier) {
  return switch (tier) {
    ExperienceTier.starter => Icons.workspace_premium_rounded,
    ExperienceTier.rising => Icons.emoji_events_rounded,
    ExperienceTier.premium => Icons.military_tech_rounded,
    ExperienceTier.elite => Icons.shield_rounded,
    ExperienceTier.royal => Icons.diamond_rounded,
    ExperienceTier.sovereign => Icons.local_fire_department_rounded,
    ExperienceTier.mythic => Icons.auto_awesome_rounded,
    ExperienceTier.immortal => Icons.stars_rounded,
  };
}

ExperiencePillStyle experiencePillStyleFor({
  required ExperienceLevelType type,
  required int level,
}) {
  final tier = experienceTierForLevel(level);
  final crownIcon = experienceCrownForTier(tier);

  if (type == ExperienceLevelType.sent) {
    return switch (tier) {
      ExperienceTier.starter => const ExperiencePillStyle(
          gradient: [Color(0xFF2F80FF), Color(0xFF12C7B7)],
          crownIcon: Icons.workspace_premium_rounded,
          crownColor: Color(0xFFD9F4FF),
          glowColor: Color(0xFF12C7B7),
          textColor: Colors.white,
          tier: ExperienceTier.starter,
        ),
      ExperienceTier.rising => ExperiencePillStyle(
          gradient: const [Color(0xFF155EEF), Color(0xFF0EA5E9), Color(0xFF12C7B7)],
          crownIcon: crownIcon,
          crownColor: const Color(0xFFE5F8FF),
          glowColor: const Color(0xFF0EA5E9),
          textColor: Colors.white,
          tier: tier,
        ),
      ExperienceTier.premium => ExperiencePillStyle(
          gradient: const [Color(0xFF154DFF), Color(0xFF12C7B7), Color(0xFF7A5CFF)],
          crownIcon: crownIcon,
          crownColor: const Color(0xFFE5F2FF),
          glowColor: const Color(0xFF2CCBFF),
          textColor: Colors.white,
          tier: tier,
        ),
      ExperienceTier.elite => ExperiencePillStyle(
          gradient: const [Color(0xFF0B2D89), Color(0xFF0EA5E9), Color(0xFF7C3AED)],
          crownIcon: crownIcon,
          crownColor: const Color(0xFFE0E7FF),
          glowColor: const Color(0xFF60A5FA),
          textColor: Colors.white,
          tier: tier,
        ),
      ExperienceTier.royal => ExperiencePillStyle(
          gradient: const [Color(0xFF0B1E7A), Color(0xFF0EA5E9), Color(0xFF8C5CF6), RoomColors.gold],
          crownIcon: crownIcon,
          crownColor: const Color(0xFFFFE9A6),
          glowColor: RoomColors.gold,
          textColor: Colors.white,
          tier: tier,
        ),
      ExperienceTier.sovereign => ExperiencePillStyle(
          gradient: const [Color(0xFF061A4A), Color(0xFF111827), Color(0xFF0EA5E9), Color(0xFFC084FC), Color(0xFFFFD166)],
          crownIcon: crownIcon,
          crownColor: const Color(0xFFFFECB3),
          glowColor: const Color(0xFFFFD166),
          textColor: Colors.white,
          tier: tier,
        ),
      ExperienceTier.mythic => ExperiencePillStyle(
          gradient: const [Color(0xFF06102E), Color(0xFF111827), Color(0xFF0EA5E9), Color(0xFFFFD166)],
          crownIcon: crownIcon,
          crownColor: const Color(0xFFFFF1B8),
          glowColor: const Color(0xFFFFD166),
          textColor: Colors.white,
          tier: tier,
        ),
      ExperienceTier.immortal => ExperiencePillStyle(
          gradient: const [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF38BDF8), Color(0xFFE0F2FE), Color(0xFFFFD166)],
          crownIcon: crownIcon,
          crownColor: const Color(0xFFFFFFFF),
          glowColor: const Color(0xFFE0F2FE),
          textColor: Colors.white,
          tier: tier,
        ),
    };
  }

  return switch (tier) {
    ExperienceTier.starter => const ExperiencePillStyle(
        gradient: [Color(0xFFFF4F93), Color(0xFFFF8FB3)],
        crownIcon: Icons.workspace_premium_rounded,
        crownColor: Color(0xFFFFECF5),
        glowColor: Color(0xFFFF6FA7),
        textColor: Colors.white,
        tier: ExperienceTier.starter,
      ),
    ExperienceTier.rising => ExperiencePillStyle(
        gradient: const [Color(0xFFF43F7F), Color(0xFFFF8FB3), Color(0xFFFB7185)],
        crownIcon: crownIcon,
        crownColor: const Color(0xFFFFF0F7),
        glowColor: const Color(0xFFFF6FA7),
        textColor: Colors.white,
        tier: tier,
      ),
    ExperienceTier.premium => ExperiencePillStyle(
        gradient: const [Color(0xFFE84C72), Color(0xFFFF8FB3), Color(0xFF8C5CF6)],
        crownIcon: crownIcon,
        crownColor: const Color(0xFFFFF0F7),
        glowColor: const Color(0xFFFF6FA7),
        textColor: Colors.white,
        tier: tier,
      ),
    ExperienceTier.elite => ExperiencePillStyle(
        gradient: const [Color(0xFFBE185D), Color(0xFFFF4F93), Color(0xFF7C3AED)],
        crownIcon: crownIcon,
        crownColor: const Color(0xFFFCE7F3),
        glowColor: const Color(0xFFF472B6),
        textColor: Colors.white,
        tier: tier,
      ),
    ExperienceTier.royal => ExperiencePillStyle(
        gradient: const [Color(0xFF881337), Color(0xFFE84C72), Color(0xFF8C5CF6), RoomColors.gold],
        crownIcon: crownIcon,
        crownColor: const Color(0xFFFFE9A6),
        glowColor: RoomColors.gold,
        textColor: Colors.white,
        tier: tier,
      ),
    ExperienceTier.sovereign => ExperiencePillStyle(
        gradient: const [Color(0xFF4A061D), Color(0xFF111827), Color(0xFFE84C72), Color(0xFFC084FC), Color(0xFFFFD166)],
        crownIcon: crownIcon,
        crownColor: const Color(0xFFFFECB3),
        glowColor: const Color(0xFFFFD166),
        textColor: Colors.white,
        tier: tier,
      ),
    ExperienceTier.mythic => ExperiencePillStyle(
        gradient: const [Color(0xFF2A0617), Color(0xFF111827), Color(0xFFFF4F93), Color(0xFFFFD166)],
        crownIcon: crownIcon,
        crownColor: const Color(0xFFFFF1B8),
        glowColor: const Color(0xFFFFD166),
        textColor: Colors.white,
        tier: tier,
      ),
    ExperienceTier.immortal => ExperiencePillStyle(
        gradient: const [Color(0xFF020617), Color(0xFF4A061D), Color(0xFFFF4F93), Color(0xFFFCE7F3), Color(0xFFFFD166)],
        crownIcon: crownIcon,
        crownColor: const Color(0xFFFFFFFF),
        glowColor: const Color(0xFFFCE7F3),
        textColor: Colors.white,
        tier: tier,
      ),
  };
}
