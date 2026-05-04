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
      final next = currentStart + expRequiredForLevel(level);
      if (safeExp < next) {
        return ExperienceLevelProgress(
          level: level,
          totalExp: safeExp,
          currentLevelStartExp: currentStart,
          nextLevelExp: next,
          progress: (safeExp - currentStart) / (next - currentStart),
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

  int expRequiredForLevel(int level) {
    if (level < 1) return 100;
    if (level < 50) return 100 + level * 22;
    if (level < 100) return 1800 + (level - 50) * 88;
    if (level < 150) return 7600 + (level - 100) * 260;
    if (level < maxLevel) return 23600 + (level - 150) * 680;
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
