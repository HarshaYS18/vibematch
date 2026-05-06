import 'package:flutter/material.dart';

enum LoveBondType { lover, bestie, brother, sister }

extension LoveBondTypeConfigKey on LoveBondType {
  String get configKey {
    return switch (this) {
      LoveBondType.lover => 'lover',
      LoveBondType.bestie => 'bestie',
      LoveBondType.brother => 'brother',
      LoveBondType.sister => 'sister',
    };
  }

  String get defaultTitle {
    return switch (this) {
      LoveBondType.lover => 'Lover',
      LoveBondType.bestie => 'Bestie',
      LoveBondType.brother => 'Brother',
      LoveBondType.sister => 'Sister',
    };
  }
}

class LoveBondLevelConfig {
  const LoveBondLevelConfig({
    required this.level,
    required this.requiredLoveScore,
    required this.title,
    this.rewardIds = const [],
    this.privilegeIds = const [],
  });

  final int level;
  final int requiredLoveScore;
  final String title;
  final List<String> rewardIds;
  final List<String> privilegeIds;
}

class LoveBondTaskRuleConfig {
  const LoveBondTaskRuleConfig({
    required this.id,
    required this.title,
    required this.metricLabel,
    required this.expPerUnit,
    required this.scorePerUnit,
    required this.dailyCapUnits,
    required this.icon,
  });

  final String id;
  final String title;
  final String metricLabel;
  final int expPerUnit;
  final int scorePerUnit;
  final int? dailyCapUnits;
  final IconData icon;

  String get subtitle {
    final capText = dailyCapUnits == null
        ? 'No daily score cap.'
        : 'Daily cap: $dailyCapUnits $metricLabel.';
    return '1 $metricLabel = $expPerUnit EXP = $scorePerUnit Love Score. $capText';
  }
}

class LoveBondProgramConfig {
  const LoveBondProgramConfig({
    required this.type,
    required this.levels,
    required this.taskRules,
  });

  final LoveBondType type;
  final List<LoveBondLevelConfig> levels;
  final List<LoveBondTaskRuleConfig> taskRules;

  LoveBondLevelConfig currentLevelForScore(int loveScore) {
    if (levels.isEmpty) {
      return LoveBondLevelConfig(level: 0, requiredLoveScore: 0, title: type.defaultTitle);
    }

    final sorted = [...levels]..sort((a, b) => a.level.compareTo(b.level));
    var current = sorted.first;
    for (final level in sorted) {
      if (loveScore >= level.requiredLoveScore) current = level;
    }
    return current;
  }

  LoveBondLevelConfig nextLevelForScore(int loveScore) {
    if (levels.isEmpty) {
      return LoveBondLevelConfig(level: 0, requiredLoveScore: 0, title: type.defaultTitle);
    }

    final sorted = [...levels]..sort((a, b) => a.level.compareTo(b.level));
    return sorted.firstWhere(
      (level) => loveScore < level.requiredLoveScore,
      orElse: () => sorted.last,
    );
  }
}

class LoveBondProgramRepository {
  const LoveBondProgramRepository();

  // Future backend mapping:
  // GET /love-bonds/program-config
  // GET /love-bonds/me
  //
  // Same Lv/Level rule:
  // Flutter must not hardcode love/bond level thresholds, required Love Score,
  // task EXP rules, daily caps, rewards, or privileges. Backend config should
  // control all bond progression for Lover, Bestie, Brother, and Sister bonds.
  //
  // Expected config shape:
  // {
  //   "programs": {
  //     "lover": {
  //       "levels": [
  //         {"level": 1, "required_love_score": 0, "title": "Lover", "reward_ids": [], "privilege_ids": []}
  //       ],
  //       "task_rules": [
  //         {"id": "time", "title": "Spend time together", "metric_label": "min", "exp_per_unit": 1, "score_per_unit": 1, "daily_cap_units": 60}
  //       ]
  //     }
  //   }
  // }

  LoveBondProgramConfig programForType({
    required LoveBondType type,
    Map<String, dynamic>? remoteConfig,
  }) {
    final remoteProgram = _readRemoteProgram(type: type, remoteConfig: remoteConfig);
    if (remoteProgram != null) return remoteProgram;

    return _defaultPrograms[type]!;
  }

  LoveBondProgramConfig? _readRemoteProgram({
    required LoveBondType type,
    required Map<String, dynamic>? remoteConfig,
  }) {
    final programs = remoteConfig?['programs'];
    if (programs is! Map) return null;

    final rawProgram = programs[type.configKey];
    if (rawProgram is! Map) return null;

    final levels = _parseLevels(rawProgram['levels'], fallbackTitle: type.defaultTitle);
    final taskRules = _parseTaskRules(rawProgram['task_rules']);
    if (levels.isEmpty || taskRules.isEmpty) return null;

    return LoveBondProgramConfig(type: type, levels: levels, taskRules: taskRules);
  }

  static List<LoveBondLevelConfig> _parseLevels(Object? rawLevels, {required String fallbackTitle}) {
    if (rawLevels is! List) return const [];

    final levels = <LoveBondLevelConfig>[];
    for (final rawLevel in rawLevels) {
      if (rawLevel is! Map) continue;

      final level = _readInt(rawLevel['level']);
      final requiredLoveScore = _readInt(rawLevel['required_love_score']);
      if (level == null || requiredLoveScore == null || level < 0) continue;

      levels.add(
        LoveBondLevelConfig(
          level: level,
          requiredLoveScore: requiredLoveScore,
          title: rawLevel['title']?.toString() ?? fallbackTitle,
          rewardIds: _readStringList(rawLevel['reward_ids']),
          privilegeIds: _readStringList(rawLevel['privilege_ids']),
        ),
      );
    }

    levels.sort((a, b) => a.level.compareTo(b.level));
    return levels;
  }

  static List<LoveBondTaskRuleConfig> _parseTaskRules(Object? rawRules) {
    if (rawRules is! List) return const [];

    final rules = <LoveBondTaskRuleConfig>[];
    for (final rawRule in rawRules) {
      if (rawRule is! Map) continue;

      final id = rawRule['id']?.toString();
      final title = rawRule['title']?.toString();
      final metricLabel = rawRule['metric_label']?.toString();
      final expPerUnit = _readInt(rawRule['exp_per_unit']);
      final scorePerUnit = _readInt(rawRule['score_per_unit']);
      if (id == null || title == null || metricLabel == null || expPerUnit == null || scorePerUnit == null) continue;

      rules.add(
        LoveBondTaskRuleConfig(
          id: id,
          title: title,
          metricLabel: metricLabel,
          expPerUnit: expPerUnit,
          scorePerUnit: scorePerUnit,
          dailyCapUnits: _readInt(rawRule['daily_cap_units']),
          icon: _iconForTaskId(id),
        ),
      );
    }

    return rules;
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

  static IconData _iconForTaskId(String id) {
    final normalized = id.trim().toLowerCase();
    if (normalized.contains('gift')) return Icons.card_giftcard_rounded;
    if (normalized.contains('time')) return Icons.access_time_filled_rounded;
    if (normalized.contains('room')) return Icons.mic_rounded;
    return Icons.favorite_rounded;
  }

  static final Map<LoveBondType, LoveBondProgramConfig> _defaultPrograms = {
    LoveBondType.lover: _buildDefaultProgram(type: LoveBondType.lover, timeDailyCap: 60),
    LoveBondType.bestie: _buildDefaultProgram(type: LoveBondType.bestie, timeDailyCap: 45),
    LoveBondType.brother: _buildDefaultProgram(type: LoveBondType.brother, timeDailyCap: 40),
    LoveBondType.sister: _buildDefaultProgram(type: LoveBondType.sister, timeDailyCap: 40),
  };

  static LoveBondProgramConfig _buildDefaultProgram({
    required LoveBondType type,
    required int timeDailyCap,
  }) {
    return LoveBondProgramConfig(
      type: type,
      levels: List.generate(20, (index) {
        final level = index + 1;
        return LoveBondLevelConfig(
          level: level,
          requiredLoveScore: _defaultRequiredLoveScore(level),
          title: type.defaultTitle,
          rewardIds: [
            if (level == 5) '${type.configKey}_badge_5',
            if (level == 10) '${type.configKey}_profile_effect_10',
            if (level == 20) '${type.configKey}_royal_bond_20',
          ],
          privilegeIds: [
            if (level == 10) '${type.configKey}_priority_display',
            if (level == 20) '${type.configKey}_exclusive_effect',
          ],
        );
      }),
      taskRules: [
        LoveBondTaskRuleConfig(
          id: 'time_together',
          title: 'Spend time together',
          metricLabel: 'min',
          expPerUnit: 1,
          scorePerUnit: 1,
          dailyCapUnits: timeDailyCap,
          icon: Icons.access_time_filled_rounded,
        ),
        const LoveBondTaskRuleConfig(
          id: 'relationship_gifts',
          title: 'Exchange relationship gifts',
          metricLabel: 'coin',
          expPerUnit: 1,
          scorePerUnit: 1,
          dailyCapUnits: null,
          icon: Icons.card_giftcard_rounded,
        ),
      ],
    );
  }

  static int _defaultRequiredLoveScore(int level) {
    if (level <= 1) return 0;
    if (level <= 5) return (level - 1) * 500;
    if (level <= 10) return 2000 + ((level - 5) * 1400);
    if (level <= 15) return 9000 + ((level - 10) * 3600);
    return 27000 + ((level - 15) * 8500);
  }
}

class LoveBondCardData {
  const LoveBondCardData({
    required this.type,
    required this.title,
    required this.level,
    required this.displayName,
    required this.partnerName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.icon,
    required this.badgeIcon,
    required this.leftAvatarInitial,
    required this.rightAvatarInitial,
    this.loveScore = 0,
    this.nextLevelLoveScore = 0,
    this.rewardIds = const [],
    this.privilegeIds = const [],
  });

  final LoveBondType type;
  final String title;
  final int level;
  final String displayName;
  final String partnerName;
  final Color primaryColor;
  final Color secondaryColor;
  final IconData icon;
  final IconData badgeIcon;
  final String leftAvatarInitial;
  final String rightAvatarInitial;
  final int loveScore;
  final int nextLevelLoveScore;
  final List<String> rewardIds;
  final List<String> privilegeIds;
}

class LoveBondTaskData {
  const LoveBondTaskData({
    required this.title,
    required this.subtitle,
    required this.progressLabel,
    required this.progress,
    required this.reward,
    required this.icon,
    required this.capped,
    this.ruleId,
  });

  final String title;
  final String subtitle;
  final String progressLabel;
  final double progress;
  final int reward;
  final IconData icon;
  final bool capped;
  final String? ruleId;
}

final List<LoveBondCardData> mockLoveBondCards = [
  _bondCard(type: LoveBondType.lover, loveScore: 3600, displayName: 'REPSARAH → ♡', partnerName: 'Repsarah', primaryColor: const Color(0xFFFF5AAA), secondaryColor: const Color(0xFFFFC2DC), icon: Icons.home_rounded, badgeIcon: Icons.favorite_rounded, leftAvatarInitial: 'S', rightAvatarInitial: 'R'),
  _bondCard(type: LoveBondType.bestie, loveScore: 1650, displayName: 'RIDE OR DIE → ☆', partnerName: 'Aadhya', primaryColor: const Color(0xFF9C5CFF), secondaryColor: const Color(0xFFE2CCFF), icon: Icons.night_shelter_rounded, badgeIcon: Icons.favorite_rounded, leftAvatarInitial: 'A', rightAvatarInitial: 'M'),
  _bondCard(type: LoveBondType.brother, loveScore: 650, displayName: 'BRO CODE → ⚡', partnerName: 'Kiran', primaryColor: const Color(0xFF4C8DFF), secondaryColor: const Color(0xFFCFE2FF), icon: Icons.sports_esports_rounded, badgeIcon: Icons.bolt_rounded, leftAvatarInitial: 'K', rightAvatarInitial: 'V'),
  _bondCard(type: LoveBondType.sister, loveScore: 780, displayName: 'SOUL SISTERS → ✿', partnerName: 'Nithya', primaryColor: const Color(0xFFFFA93D), secondaryColor: const Color(0xFFFFE0A8), icon: Icons.diamond_rounded, badgeIcon: Icons.local_florist_rounded, leftAvatarInitial: 'N', rightAvatarInitial: 'P'),
];

LoveBondCardData _bondCard({
  required LoveBondType type,
  required int loveScore,
  required String displayName,
  required String partnerName,
  required Color primaryColor,
  required Color secondaryColor,
  required IconData icon,
  required IconData badgeIcon,
  required String leftAvatarInitial,
  required String rightAvatarInitial,
}) {
  final program = const LoveBondProgramRepository().programForType(type: type);
  final current = program.currentLevelForScore(loveScore);
  final next = program.nextLevelForScore(loveScore);

  return LoveBondCardData(
    type: type,
    title: current.title,
    level: current.level,
    displayName: displayName,
    partnerName: partnerName,
    primaryColor: primaryColor,
    secondaryColor: secondaryColor,
    icon: icon,
    badgeIcon: badgeIcon,
    leftAvatarInitial: leftAvatarInitial,
    rightAvatarInitial: rightAvatarInitial,
    loveScore: loveScore,
    nextLevelLoveScore: next.requiredLoveScore,
    rewardIds: current.rewardIds,
    privilegeIds: current.privilegeIds,
  );
}

List<LoveBondTaskData> _tasksForProgram({
  required LoveBondType type,
  required int timeProgressUnits,
  required int giftProgressUnits,
}) {
  final program = const LoveBondProgramRepository().programForType(type: type);
  return program.taskRules.map((rule) {
    final progressUnits = rule.id.contains('gift') ? giftProgressUnits : timeProgressUnits;
    final cap = rule.dailyCapUnits;
    final progress = cap == null || cap <= 0 ? 0.58 : (progressUnits / cap).clamp(0.0, 1.0).toDouble();
    final progressLabel = cap == null ? '$progressUnits / ∞ ${rule.metricLabel}' : '$progressUnits / $cap ${rule.metricLabel}';
    return LoveBondTaskData(
      title: rule.title,
      subtitle: rule.subtitle,
      progressLabel: progressLabel,
      progress: progress,
      reward: progressUnits * rule.scorePerUnit,
      icon: rule.icon,
      capped: cap != null,
      ruleId: rule.id,
    );
  }).toList();
}

List<LoveBondTaskData> get mockLoverTasks => _tasksForProgram(type: LoveBondType.lover, timeProgressUnits: 45, giftProgressUnits: 450);
List<LoveBondTaskData> get mockBestieTasks => _tasksForProgram(type: LoveBondType.bestie, timeProgressUnits: 22, giftProgressUnits: 320);
List<LoveBondTaskData> get mockBrotherTasks => _tasksForProgram(type: LoveBondType.brother, timeProgressUnits: 18, giftProgressUnits: 260);
List<LoveBondTaskData> get mockSisterTasks => _tasksForProgram(type: LoveBondType.sister, timeProgressUnits: 28, giftProgressUnits: 260);

List<LoveBondTaskData> tasksForBondType(LoveBondType type) {
  return switch (type) {
    LoveBondType.lover => mockLoverTasks,
    LoveBondType.bestie => mockBestieTasks,
    LoveBondType.brother => mockBrotherTasks,
    LoveBondType.sister => mockSisterTasks,
  };
}
