import '../models/level_program_models.dart';

class LevelProgramConfigRepository {
  const LevelProgramConfigRepository();

  // Future backend mapping:
  // GET /levels/program-config
  // GET /levels/me
  //
  // This is the single rule for every place that displays Lv / Level:
  // Flutter must not decide required coins, EXP, thresholds, capacities, or
  // level rewards locally. Flutter should render the config returned by backend.
  //
  // Applies to:
  // - VIP level
  // - SVIP monthly level
  // - Family level
  // - Send Lv
  // - Receive Lv
  // - Room Lv
  //
  // Backend/admin config should control:
  // - level number and display label
  // - required metric amount for each level
  // - difficulty/progression label
  // - reward IDs / privilege IDs
  // - reset/drop policy where applicable
  // - per-level metadata such as max members, admin capacity, VIP requirement
  //
  // Expected remote config shape:
  // {
  //   "programs": {
  //     "send": {
  //       "metric_key": "lifetime_sent_gift_coins",
  //       "metric_label": "lifetime sent gift coins",
  //       "levels": [
  //         {"level": 1, "required_value": 0, "display_label": "Send Lv 1", "reward_ids": []}
  //       ]
  //     },
  //     "receive": {
  //       "metric_key": "lifetime_received_gift_coins",
  //       "metric_label": "lifetime received gift coins",
  //       "levels": []
  //     },
  //     "room": {
  //       "metric_key": "room_activity_exp",
  //       "metric_label": "room activity EXP",
  //       "levels": []
  //     }
  //   }
  // }

  LevelProgramConfig parseProgramConfig({
    required LevelProgramType type,
    required Map<String, dynamic>? remoteConfig,
    required LevelProgramConfig fallback,
  }) {
    final programs = remoteConfig?['programs'];
    if (programs is! Map) return fallback;

    final rawProgram = programs[type.apiKey];
    if (rawProgram is! Map) return fallback;

    final levels = _parseLevelSteps(rawProgram['levels'], type: type);
    if (levels.isEmpty) return fallback;

    return LevelProgramConfig(
      type: type,
      metricKey: rawProgram['metric_key']?.toString() ?? fallback.metricKey,
      metricLabel: rawProgram['metric_label']?.toString() ?? fallback.metricLabel,
      levels: levels,
      resetPolicy: rawProgram['reset_policy']?.toString() ?? fallback.resetPolicy,
      dropPolicy: rawProgram['drop_policy']?.toString() ?? fallback.dropPolicy,
      meta: _readMeta(rawProgram['meta']),
    );
  }

  List<LevelStepConfig> _parseLevelSteps(Object? rawLevels, {required LevelProgramType type}) {
    if (rawLevels is! List) return const [];

    final levels = <LevelStepConfig>[];
    for (final rawLevel in rawLevels) {
      if (rawLevel is! Map) continue;

      final level = _readInt(rawLevel['level']);
      final requiredValue = _readInt(rawLevel['required_value']);
      if (level == null || requiredValue == null || level < 0) continue;

      levels.add(
        LevelStepConfig(
          level: level,
          requiredValue: requiredValue,
          displayLabel: rawLevel['display_label']?.toString() ?? '${type.displayLabel} $level',
          difficultyLabel: rawLevel['difficulty_label']?.toString(),
          rewardIds: _readStringList(rawLevel['reward_ids']),
          meta: _readMeta(rawLevel['meta']),
        ),
      );
    }

    levels.sort((a, b) => a.level.compareTo(b.level));
    return levels;
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

  static Map<String, Object?> _readMeta(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
}
