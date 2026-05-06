enum LevelProgramType {
  vip,
  svip,
  family,
  send,
  receive,
  room,
}

extension LevelProgramTypeApiKey on LevelProgramType {
  String get apiKey {
    switch (this) {
      case LevelProgramType.vip:
        return 'vip';
      case LevelProgramType.svip:
        return 'svip';
      case LevelProgramType.family:
        return 'family';
      case LevelProgramType.send:
        return 'send';
      case LevelProgramType.receive:
        return 'receive';
      case LevelProgramType.room:
        return 'room';
    }
  }

  String get displayLabel {
    switch (this) {
      case LevelProgramType.vip:
        return 'VIP';
      case LevelProgramType.svip:
        return 'SVIP';
      case LevelProgramType.family:
        return 'Family Lv';
      case LevelProgramType.send:
        return 'Send Lv';
      case LevelProgramType.receive:
        return 'Receive Lv';
      case LevelProgramType.room:
        return 'Room Lv';
    }
  }
}

class LevelStepConfig {
  const LevelStepConfig({
    required this.level,
    required this.requiredValue,
    required this.displayLabel,
    this.difficultyLabel,
    this.rewardIds = const [],
    this.meta = const {},
  });

  final int level;
  final int requiredValue;
  final String displayLabel;
  final String? difficultyLabel;
  final List<String> rewardIds;
  final Map<String, Object?> meta;
}

class LevelProgramConfig {
  const LevelProgramConfig({
    required this.type,
    required this.metricKey,
    required this.metricLabel,
    required this.levels,
    this.resetPolicy,
    this.dropPolicy,
    this.meta = const {},
  });

  final LevelProgramType type;
  final String metricKey;
  final String metricLabel;
  final List<LevelStepConfig> levels;
  final String? resetPolicy;
  final String? dropPolicy;
  final Map<String, Object?> meta;

  LevelStepConfig currentLevelForValue(int value) {
    if (levels.isEmpty) {
      return LevelStepConfig(
        level: 0,
        requiredValue: 0,
        displayLabel: '${type.displayLabel} 0',
      );
    }

    final sorted = [...levels]..sort((a, b) => a.level.compareTo(b.level));
    var current = sorted.first;
    for (final level in sorted) {
      if (value >= level.requiredValue) current = level;
    }
    return current;
  }

  LevelStepConfig nextLevelForValue(int value) {
    if (levels.isEmpty) {
      return LevelStepConfig(
        level: 0,
        requiredValue: 0,
        displayLabel: '${type.displayLabel} 0',
      );
    }

    final sorted = [...levels]..sort((a, b) => a.level.compareTo(b.level));
    return sorted.firstWhere(
      (level) => value < level.requiredValue,
      orElse: () => sorted.last,
    );
  }

  double progressForValue(int value) {
    final current = currentLevelForValue(value);
    final next = nextLevelForValue(value);
    if (next.level == current.level || next.requiredValue <= current.requiredValue) return 1;

    return ((value - current.requiredValue) / (next.requiredValue - current.requiredValue)).clamp(0.0, 1.0).toDouble();
  }
}

class LevelProgramSnapshot {
  const LevelProgramSnapshot({
    required this.config,
    required this.currentValue,
  });

  final LevelProgramConfig config;
  final int currentValue;

  LevelStepConfig get currentLevel => config.currentLevelForValue(currentValue);
  LevelStepConfig get nextLevel => config.nextLevelForValue(currentValue);
  double get progress => config.progressForValue(currentValue);

  int get valueRequiredForNextLevel =>
      (nextLevel.requiredValue - currentValue).clamp(0, 1 << 31).toInt();
}
