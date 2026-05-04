import 'package:flutter/material.dart';

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
          RoomToast.show(context, 'Crystal Hunt opens here');
        },
        onLudoTap: () {
          Navigator.pop(context);
          RoomToast.show(context, 'Ludo opens here');
        },
        onCarromTap: () {
          Navigator.pop(context);
          RoomToast.show(context, 'Carrom opens here');
        },
        onPkTap: () {
          Navigator.pop(context);
          RoomToast.show(context, 'PK game opens here');
        },
      ),
    );
  }
}
