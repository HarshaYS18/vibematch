import 'package:flutter/material.dart';

import '../../../games/presentation/game_test_page.dart';
import '../controllers/live_room_sheet_controller.dart';
import '../widgets/live_room_games_sheet.dart';
import '../widgets/room_theme.dart';

class LiveRoomGamesActionsModule {
  const LiveRoomGamesActionsModule._();

  static Future<void> openGamesSheet({
    required BuildContext context,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();

    return LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      builder: (_) => LiveRoomGamesSheet(
        onCrystalHuntTap: () {
          Navigator.pop(context);
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameTestPage()));
        },
        onLudoTap: () {
          Navigator.pop(context);
          RoomToast.show(context, 'Ludo will connect to backend game catalog after free-game module is added.');
        },
        onCarromTap: () {
          Navigator.pop(context);
          RoomToast.show(context, 'Carrom will connect to backend game catalog after free-game module is added.');
        },
        onPkTap: () {
          Navigator.pop(context);
          RoomToast.show(context, 'PK game will connect to backend room battle flow after PK backend is added.');
        },
      ),
    );
  }
}
