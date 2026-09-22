import 'package:flutter/material.dart';

import '../../../games/presentation/coin_game_rankings_sheet.dart';
import '../../../../game_platform/presentation/remote_game_player_page.dart';
import '../controllers/live_room_sheet_controller.dart';
import '../widgets/live_room_games_sheet.dart';

class LiveRoomGamesActionsModule {
  const LiveRoomGamesActionsModule._();

  static Future<void> openGamesSheet({
    required BuildContext context,
    required String roomId,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();

    return LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      builder: (_) => LiveRoomGamesSheet(
        onJungleHuntTap: () {
          Navigator.pop(context);
          LiveRoomSheetController.showTransparentSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => FractionallySizedBox(
              heightFactor: 0.70,
              alignment: Alignment.bottomCenter,
              child: RemoteGamePlayerPage(
                gameId: 'jungle_hunt',
                roomId: roomId,
                embeddedInRoom: true,
              ),
            ),
          );
        },
        onCoinGameRankingsTap: () {
          Navigator.pop(context);
          CoinGameRankingsSheet.show(context);
        },
      ),
    );
  }
}
