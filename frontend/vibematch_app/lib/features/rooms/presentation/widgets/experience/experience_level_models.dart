import 'package:flutter/material.dart';

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

  if (type == ExperienceLevelType.sent) {
    final sentGradients = <List<Color>>[
      const [Color(0xFF15C7FF), Color(0xFF0B6BFF), Color(0xFF39FFCF)],
      const [Color(0xFF0047FF), Color(0xFF00D4FF), Color(0xFF00A884)],
      const [Color(0xFF2D00F7), Color(0xFF009DFF), Color(0xFF00FFC2)],
      const [Color(0xFF0619A8), Color(0xFF19B7FF), Color(0xFF8A2BE2)],
      const [Color(0xFF001D5C), Color(0xFF00B8FF), Color(0xFFC084FC)],
      const [Color(0xFF03143F), Color(0xFF0066FF), Color(0xFFFFD166)],
      const [Color(0xFF020617), Color(0xFF0047AB), Color(0xFF00E5FF), Color(0xFFFFC857)],
      const [Color(0xFF020617), Color(0xFF111827), Color(0xFF2DD4BF), Color(0xFFFFD166)],
      const [Color(0xFF000000), Color(0xFF0B1120), Color(0xFF67E8F9), Color(0xFFFFFFFF), Color(0xFFFFD166)],
      const [Color(0xFF000000), Color(0xFF020617), Color(0xFFBDEBFF), Color(0xFFFFFFFF), Color(0xFFFFB703)],
    ];
    final crownColors = const [
      Color(0xFFE6FBFF),
      Color(0xFFE0F7FF),
      Color(0xFFE7E9FF),
      Color(0xFFF1E8FF),
      Color(0xFFE9D5FF),
      Color(0xFFFFE9A6),
      Color(0xFFFFF0B8),
      Color(0xFFFFF4C7),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
    ];
    final glowColors = const [
      Color(0xFF15C7FF),
      Color(0xFF00D4FF),
      Color(0xFF7A5CFF),
      Color(0xFF8A2BE2),
      Color(0xFFC084FC),
      Color(0xFFFFD166),
      Color(0xFF00E5FF),
      Color(0xFFFFD166),
      Color(0xFFFFFFFF),
      Color(0xFFFFB703),
    ];

    return ExperiencePillStyle(
      gradient: sentGradients[band],
      crownIcon: crownIcon,
      crownColor: crownColors[band],
      glowColor: glowColors[band],
      textColor: Colors.white,
      tier: tier,
    );
  }

  final receivedGradients = <List<Color>>[
    const [Color(0xFFFF5CA8), Color(0xFFFF2E75), Color(0xFFFFB3D1)],
    const [Color(0xFFE6007E), Color(0xFFFF6FA7), Color(0xFFFF8A00)],
    const [Color(0xFFC9184A), Color(0xFFFF4F93), Color(0xFF8C5CF6)],
    const [Color(0xFF9D174D), Color(0xFFFF2E75), Color(0xFF7C3AED)],
    const [Color(0xFF6D0028), Color(0xFFFF4F93), Color(0xFFA855F7)],
    const [Color(0xFF4A061D), Color(0xFFE84C72), Color(0xFFFFD166)],
    const [Color(0xFF2A0617), Color(0xFF7F1D1D), Color(0xFFFF4F93), Color(0xFFC084FC)],
    const [Color(0xFF18020B), Color(0xFF111827), Color(0xFFFF2E75), Color(0xFFFFD166)],
    const [Color(0xFF000000), Color(0xFF4A061D), Color(0xFFFF8FB3), Color(0xFFFFFFFF), Color(0xFFFFD166)],
    const [Color(0xFF000000), Color(0xFF2A0617), Color(0xFFFFC7DF), Color(0xFFFFFFFF), Color(0xFFFFB703)],
  ];
  final crownColors = const [
    Color(0xFFFFECF5),
    Color(0xFFFFF0D8),
    Color(0xFFFFECF5),
    Color(0xFFF5E8FF),
    Color(0xFFFFD7EA),
    Color(0xFFFFE9A6),
    Color(0xFFFFE0F1),
    Color(0xFFFFF1B8),
    Color(0xFFFFFFFF),
    Color(0xFFFFFFFF),
  ];
  final glowColors = const [
    Color(0xFFFF5CA8),
    Color(0xFFFF8A00),
    Color(0xFF8C5CF6),
    Color(0xFF7C3AED),
    Color(0xFFA855F7),
    Color(0xFFFFD166),
    Color(0xFFC084FC),
    Color(0xFFFFD166),
    Color(0xFFFFFFFF),
    Color(0xFFFFB703),
  ];

  return ExperiencePillStyle(
    gradient: receivedGradients[band],
    crownIcon: crownIcon,
    crownColor: crownColors[band],
    glowColor: glowColors[band],
    textColor: Colors.white,
    tier: tier,
  );
}
