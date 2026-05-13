import 'package:flutter/material.dart';

import '../../../games/presentation/jungle_hunt_game_page.dart';
import '../controllers/live_room_sheet_controller.dart';
import '../widgets/live_room_games_sheet.dart';

class LiveRoomGamesActionsModule {
  const LiveRoomGamesActionsModule._();

  static Future<void> openGamesSheet({
    required BuildContext context,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();

    return LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      builder: (_) => LiveRoomGamesSheet(
        onJungleHuntTap: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const JungleHuntGamePage()),
          );
        },
      ),
    );
  }
}
