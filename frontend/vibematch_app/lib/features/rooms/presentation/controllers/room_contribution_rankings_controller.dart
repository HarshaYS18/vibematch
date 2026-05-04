import '../live_room_models.dart';

class RoomContributionRankingsController {
  const RoomContributionRankingsController();

  List<SeatUser> rankedUsers({
    required List<SeatUser> users,
    required RoomContributionPeriod period,
  }) {
    final rankedUsers = List<SeatUser>.from(users);
    rankedUsers.sort((a, b) => scoreFor(b, period).compareTo(scoreFor(a, period)));
    return rankedUsers;
  }

  int scoreFor(SeatUser user, RoomContributionPeriod period) {
    final base = user.sentExp + (user.receivedExp ~/ 2) + (user.vipLevel * 250);
    switch (period) {
      case RoomContributionPeriod.today:
        return (base * 0.13).round() + (user.sendingLevel * 18);
      case RoomContributionPeriod.thisWeek:
        return (base * 0.46).round() + (user.receivingLevel * 42);
    }
  }
}

enum RoomContributionPeriod { today, thisWeek }
