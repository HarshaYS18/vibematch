import 'package:flutter/material.dart';

import '../../../games/galactic_spins/galactic_spins_page.dart';
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
        onGalacticSpinsTap: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const GalacticSpinsPage(),
            ),
          );
        },
      ),
    );
  }
}
