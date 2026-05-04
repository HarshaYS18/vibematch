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
  premium,
  royal,
  mythic;

  String get label => switch (this) {
        ExperienceTier.starter => 'Starter',
        ExperienceTier.premium => 'Premium',
        ExperienceTier.royal => 'Royal',
        ExperienceTier.mythic => 'Mythic',
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

ExperiencePillStyle experiencePillStyleFor({
  required ExperienceLevelType type,
  required int level,
}) {
  final tier = level >= 150
      ? ExperienceTier.mythic
      : level >= 100
          ? ExperienceTier.royal
          : level >= 50
              ? ExperienceTier.premium
              : ExperienceTier.starter;

  final crownIcon = switch (tier) {
    ExperienceTier.starter => Icons.workspace_premium_rounded,
    ExperienceTier.premium => Icons.military_tech_rounded,
    ExperienceTier.royal => Icons.diamond_rounded,
    ExperienceTier.mythic => Icons.auto_awesome_rounded,
  };

  if (type == ExperienceLevelType.sent) {
    return switch (tier) {
      ExperienceTier.starter => const ExperiencePillStyle(
          gradient: [Color(0xFF0E6CFF), Color(0xFF12C7B7)],
          crownIcon: Icons.workspace_premium_rounded,
          crownColor: Color(0xFFD9F4FF),
          glowColor: Color(0xFF12C7B7),
          textColor: Colors.white,
          tier: ExperienceTier.starter,
        ),
      ExperienceTier.premium => ExperiencePillStyle(
          gradient: const [Color(0xFF154DFF), Color(0xFF12C7B7), Color(0xFF7A5CFF)],
          crownIcon: crownIcon,
          crownColor: const Color(0xFFE5F2FF),
          glowColor: const Color(0xFF2CCBFF),
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
      ExperienceTier.mythic => ExperiencePillStyle(
          gradient: const [Color(0xFF06102E), Color(0xFF111827), Color(0xFF0EA5E9), Color(0xFFFFD166)],
          crownIcon: crownIcon,
          crownColor: const Color(0xFFFFF1B8),
          glowColor: const Color(0xFFFFD166),
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
    ExperienceTier.premium => ExperiencePillStyle(
        gradient: const [Color(0xFFE84C72), Color(0xFFFF8FB3), Color(0xFF8C5CF6)],
        crownIcon: crownIcon,
        crownColor: const Color(0xFFFFF0F7),
        glowColor: const Color(0xFFFF6FA7),
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
    ExperienceTier.mythic => ExperiencePillStyle(
        gradient: const [Color(0xFF2A0617), Color(0xFF111827), Color(0xFFFF4F93), Color(0xFFFFD166)],
        crownIcon: crownIcon,
        crownColor: const Color(0xFFFFF1B8),
        glowColor: const Color(0xFFFFD166),
        textColor: Colors.white,
        tier: tier,
      ),
  };
}
