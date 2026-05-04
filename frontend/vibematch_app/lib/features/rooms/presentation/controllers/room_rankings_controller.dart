import '../live_room_models.dart';
import '../widgets/rankings/room_rankings_models.dart';

class RoomRankingsController {
  const RoomRankingsController();

  String backendPath({
    required String roomPublicId,
    required RoomRankingCategory category,
    required RoomRankingPeriod period,
  }) {
    return '/rooms/$roomPublicId/rankings/${category.backendValue}?period=${period.backendValue}';
  }

  List<RoomRankingEntry> buildMockEntries({
    required List<SeatUser> users,
    required RoomRankingCategory category,
    required RoomRankingPeriod period,
  }) {
    final rankedUsers = List<SeatUser>.from(users);
    rankedUsers.sort((a, b) => _scoreFor(b, category, period).compareTo(_scoreFor(a, category, period)));

    return [
      for (var index = 0; index < rankedUsers.length; index++)
        RoomRankingEntry(
          rank: index + 1,
          user: rankedUsers[index],
          score: _scoreFor(rankedUsers[index], category, period),
          scoreText: _scoreTextFor(rankedUsers[index], category, period),
          scoreLabel: _scoreLabelFor(category),
          subtitle: _subtitleFor(rankedUsers[index], category),
        ),
    ];
  }

  int _scoreFor(SeatUser user, RoomRankingCategory category, RoomRankingPeriod period) {
    final periodMultiplier = switch (period) {
      RoomRankingPeriod.daily => 0.18,
      RoomRankingPeriod.weekly => 0.52,
      RoomRankingPeriod.monthly => 1.0,
    };

    final base = switch (category) {
      RoomRankingCategory.wealth => _coinRechargeForPeriod(user, period),
      RoomRankingCategory.sent => user.sentExp + user.sendingLevel * 420,
      RoomRankingCategory.received => user.receivedExp + user.receivingLevel * 420,
      RoomRankingCategory.relation => _loveAndBondsScoreForPeriod(user, period),
    };

    if (category == RoomRankingCategory.wealth || category == RoomRankingCategory.relation) {
      return base;
    }
    return (base * periodMultiplier).round();
  }

  int _coinRechargeForPeriod(SeatUser user, RoomRankingPeriod period) {
    final lifetimeRechargeEstimate = user.vipLevel * 7800 + user.sentExp ~/ 3;
    return switch (period) {
      RoomRankingPeriod.daily => (lifetimeRechargeEstimate * 0.08).round(),
      RoomRankingPeriod.weekly => (lifetimeRechargeEstimate * 0.34).round(),
      RoomRankingPeriod.monthly => lifetimeRechargeEstimate,
    };
  }

  int _loveAndBondsScoreForPeriod(SeatUser user, RoomRankingPeriod period) {
    final lifetimeLoveScore = user.receivedExp ~/ 2 + user.sentExp ~/ 2 + user.vipLevel * 520;
    return switch (period) {
      RoomRankingPeriod.daily => (lifetimeLoveScore * 0.10).round(),
      RoomRankingPeriod.weekly => (lifetimeLoveScore * 0.38).round(),
      RoomRankingPeriod.monthly => lifetimeLoveScore,
    };
  }

  String _scoreTextFor(SeatUser user, RoomRankingCategory category, RoomRankingPeriod period) {
    final score = _scoreFor(user, category, period);
    if (category == RoomRankingCategory.wealth) return _maskCoinAmount(score);
    return _compactNumber(score);
  }

  String _maskCoinAmount(int value) {
    final raw = value.abs().toString();
    if (raw.length <= 3) return raw;
    final hiddenCount = raw.length - 3;
    return '${raw.substring(0, 2)}${'*' * hiddenCount}${raw.substring(raw.length - 1)}';
  }

  String _compactNumber(int value) {
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(value % 1000000000 == 0 ? 0 : 1)}B';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    return '$value';
  }

  String _scoreLabelFor(RoomRankingCategory category) {
    return switch (category) {
      RoomRankingCategory.wealth => 'coin',
      RoomRankingCategory.sent => 'sent',
      RoomRankingCategory.received => 'received',
      RoomRankingCategory.relation => 'Love & Bonds',
    };
  }

  String _subtitleFor(SeatUser user, RoomRankingCategory category) {
    return switch (category) {
      RoomRankingCategory.wealth => 'VIP ${user.vipLevel}',
      RoomRankingCategory.sent => 'Sending Lv ${user.sendingLevel}',
      RoomRankingCategory.received => 'Receiving Lv ${user.receivingLevel}',
      RoomRankingCategory.relation => 'Love & Bonds score',
    };
  }
}
