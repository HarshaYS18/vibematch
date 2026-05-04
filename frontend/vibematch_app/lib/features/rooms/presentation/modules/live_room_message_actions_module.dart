import 'package:flutter/material.dart';

import '../controllers/live_room_mention_text_controller.dart';
import 'live_room_message_composer_module.dart';

class LiveRoomMessageActionsModule {
  const LiveRoomMessageActionsModule._();

  static Future<void> openComposer({
    required BuildContext context,
    required LiveRoomMentionTextController controller,
    required FocusNode focusNode,
    required bool imagesEnabled,
    required VoidCallback onSendText,
    required VoidCallback onImageTap,
    required VoidCallback onSendFloatingText,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (_) => LiveRoomMessageComposerModule(
        controller: controller,
        focusNode: focusNode,
        imagesEnabled: imagesEnabled,
        onSendText: onSendText,
        onImageTap: onImageTap,
        onSendFloatingText: onSendFloatingText,
      ),
    );
  }
}
