import 'package:flutter/material.dart';

import '../controllers/live_room_sheet_controller.dart';
import '../widgets/live_room_emoji_sheet.dart';
import '../widgets/room_theme.dart';

class LiveRoomEmojiActionsModule {
  const LiveRoomEmojiActionsModule._();

  static Future<void> openEmojiTray({
    required BuildContext context,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();

    return LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      builder: (_) => LiveRoomEmojiSheet(
        onEmojiTap: (emoji) {
          Navigator.pop(context);
          RoomToast.show(context, '$emoji reaction will animate over avatar');
        },
      ),
    );
  }
}
