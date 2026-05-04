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
      RoomRankingCategory.wealth => user.vipLevel * 900 + user.sentExp + user.receivedExp,
      RoomRankingCategory.sent => user.sentExp + user.sendingLevel * 420,
      RoomRankingCategory.received => user.receivedExp + user.receivingLevel * 420,
      RoomRankingCategory.relation => user.receivedExp ~/ 2 + user.sentExp ~/ 2 + user.vipLevel * 520,
    };

    return (base * periodMultiplier).round();
  }

  String _scoreLabelFor(RoomRankingCategory category) {
    return switch (category) {
      RoomRankingCategory.wealth => 'wealth',
      RoomRankingCategory.sent => 'sent',
      RoomRankingCategory.received => 'received',
      RoomRankingCategory.relation => 'bond',
    };
  }

  String _subtitleFor(SeatUser user, RoomRankingCategory category) {
    return switch (category) {
      RoomRankingCategory.wealth => 'VIP ${user.vipLevel} · Global wealth',
      RoomRankingCategory.sent => 'Sending Lv ${user.sendingLevel} · Global sent',
      RoomRankingCategory.received => 'Receiving Lv ${user.receivingLevel} · Global received',
      RoomRankingCategory.relation => user.familyName.trim().isEmpty ? 'Global relation score' : user.familyName,
    };
  }
}
