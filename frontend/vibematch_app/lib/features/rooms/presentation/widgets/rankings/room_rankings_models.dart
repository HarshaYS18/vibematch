import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import '../room_theme.dart';

enum RoomRankingCategory {
  wealth,
  sent,
  received,
  relation;

  String get label => switch (this) {
        RoomRankingCategory.wealth => 'Wealth',
        RoomRankingCategory.sent => 'Sent',
        RoomRankingCategory.received => 'Received',
        RoomRankingCategory.relation => 'Relation',
      };

  String get title => switch (this) {
        RoomRankingCategory.wealth => 'Wealth Ranking',
        RoomRankingCategory.sent => 'Sent Ranking',
        RoomRankingCategory.received => 'Received Ranking',
        RoomRankingCategory.relation => 'Relation Ranking',
      };

  String get backendValue => switch (this) {
        RoomRankingCategory.wealth => 'wealth',
        RoomRankingCategory.sent => 'sent',
        RoomRankingCategory.received => 'received',
        RoomRankingCategory.relation => 'relation',
      };

  IconData get icon => switch (this) {
        RoomRankingCategory.wealth => Icons.diamond_rounded,
        RoomRankingCategory.sent => Icons.north_east_rounded,
        RoomRankingCategory.received => Icons.card_giftcard_rounded,
        RoomRankingCategory.relation => Icons.favorite_rounded,
      };

  Color get accentColor => switch (this) {
        RoomRankingCategory.wealth => RoomColors.gold,
        RoomRankingCategory.sent => RoomColors.coral,
        RoomRankingCategory.received => RoomColors.aqua,
        RoomRankingCategory.relation => RoomColors.violet,
      };
}

enum RoomRankingPeriod {
  daily,
  weekly,
  monthly;

  String get label => switch (this) {
        RoomRankingPeriod.daily => 'Daily',
        RoomRankingPeriod.weekly => 'Weekly',
        RoomRankingPeriod.monthly => 'Monthly',
      };

  String get backendValue => switch (this) {
        RoomRankingPeriod.daily => 'daily',
        RoomRankingPeriod.weekly => 'weekly',
        RoomRankingPeriod.monthly => 'monthly',
      };
}

class RoomRankingEntry {
  const RoomRankingEntry({
    required this.rank,
    required this.user,
    required this.score,
    required this.scoreText,
    required this.scoreLabel,
    required this.subtitle,
  });

  final int rank;
  final SeatUser user;
  final int score;
  final String scoreText;
  final String scoreLabel;
  final String subtitle;

  String get displayRank {
    if (rank > 99) return '99+';
    return '$rank';
  }
}
