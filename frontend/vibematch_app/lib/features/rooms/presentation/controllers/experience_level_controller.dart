import '../widgets/experience/experience_level_models.dart';

class ExperienceLevelController {
  const ExperienceLevelController();

  static const int maxLevel = 200;
  static const int timeSpentExpPerFiveMinutes = 20;
  static const int maxDailyTimeSpentExp = 800;
  static const int coinExpCoinUnit = 20;
  static const int coinExpReward = 2;

  String backendPath({required ExperienceLevelType type, required String userId}) {
    return '/users/$userId/experience/${type.backendValue}';
  }

  int timeSpentExpForMinutes(int minutesSpentToday) {
    final fiveMinuteBlocks = minutesSpentToday ~/ 5;
    final exp = fiveMinuteBlocks * timeSpentExpPerFiveMinutes;
    return exp.clamp(0, maxDailyTimeSpentExp);
  }

  int sentGiftExpForCoins(int coinsSent) => _coinBasedExp(coinsSent);

  int storePurchaseExpForCoins(int coinsSpent) => _coinBasedExp(coinsSpent);

  int receivedGiftExpForCoins(int coinsReceived) => _coinBasedExp(coinsReceived);

  int sentTotalEarnedExp({
    required int minutesSpentToday,
    required int giftCoinsSent,
    required int storeCoinsSpent,
  }) {
    return timeSpentExpForMinutes(minutesSpentToday) + sentGiftExpForCoins(giftCoinsSent) + storePurchaseExpForCoins(storeCoinsSpent);
  }

  int receivedTotalEarnedExp({required int giftCoinsReceived}) {
    return receivedGiftExpForCoins(giftCoinsReceived);
  }

  ExperienceLevelProgress progressForTotalExp(int totalExp) {
    final safeExp = totalExp < 0 ? 0 : totalExp;
    var level = 1;
    var currentStart = 0;

    while (level < maxLevel) {
      final requiredForThisLevel = expRequiredToFinishLevel(level);
      final next = currentStart + requiredForThisLevel;
      if (safeExp < next) {
        return ExperienceLevelProgress(
          level: level,
          totalExp: safeExp,
          currentLevelStartExp: currentStart,
          nextLevelExp: next,
          progress: (safeExp - currentStart) / requiredForThisLevel,
          tier: tierForLevel(level),
        );
      }
      currentStart = next;
      level++;
    }

    return ExperienceLevelProgress(
      level: maxLevel,
      totalExp: safeExp,
      currentLevelStartExp: currentStart,
      nextLevelExp: currentStart,
      progress: 1,
      tier: tierForLevel(maxLevel),
    );
  }

  int totalExpRequiredToReachLevel(int targetLevel) {
    final safeLevel = targetLevel.clamp(1, maxLevel);
    var total = 0;
    for (var level = 1; level < safeLevel; level++) {
      total += expRequiredToFinishLevel(level);
    }
    return total;
  }

  int expRequiredToFinishLevel(int level) {
    if (level < 1) return 120;
    if (level < 10) return 120 + (level - 1) * 35;
    if (level < 25) return 460 + (level - 10) * 70;
    if (level < 50) return 1550 + (level - 25) * 135;
    if (level < 75) return 5200 + (level - 50) * 310;
    if (level < 100) return 13500 + (level - 75) * 620;
    if (level < 125) return 32000 + (level - 100) * 1250;
    if (level < 150) return 72000 + (level - 125) * 2400;
    if (level < 175) return 150000 + (level - 150) * 5200;
    if (level < maxLevel) return 320000 + (level - 175) * 11000;
    return 0;
  }

  ExperienceTier tierForLevel(int level) {
    if (level >= 150) return ExperienceTier.mythic;
    if (level >= 100) return ExperienceTier.royal;
    if (level >= 50) return ExperienceTier.premium;
    return ExperienceTier.starter;
  }

  int _coinBasedExp(int coins) {
    if (coins <= 0) return 0;
    return (coins ~/ coinExpCoinUnit) * coinExpReward;
  }
}
