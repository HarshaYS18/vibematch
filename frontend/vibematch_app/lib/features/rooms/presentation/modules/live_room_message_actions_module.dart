import 'package:flutter/material.dart';

import '../../../../core/ui/vm_motion.dart';
import '../controllers/live_room_mention_text_controller.dart';
import 'live_room_message_composer_module.dart';

/// Opens room message UI using only callbacks supplied by the owning room scope.
///
/// Seat-menu dismissal is injected from LiveRoomSeatController so this helper
/// never depends on process-global presentation state.
class LiveRoomMessageActionsModule {
  const LiveRoomMessageActionsModule._();

  static Future<void> openComposer({
    required BuildContext context,
    required LiveRoomMentionTextController controller,
    required FocusNode focusNode,
    required bool imagesEnabled,
    required VoidCallback onDismissSeatActions,
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
      sheetAnimationStyle: VmMotion.sheetAnimationStyle,
      builder: (_) => VmFadeSlide(
        child: LiveRoomMessageComposerModule(
          controller: controller,
          focusNode: focusNode,
          imagesEnabled: imagesEnabled,
          onDismissSeatActions: onDismissSeatActions,
          onSendText: onSendText,
          onImageTap: onImageTap,
          onSendFloatingText: onSendFloatingText,
        ),
      ),
    );
  }
}
