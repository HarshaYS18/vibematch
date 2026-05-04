import 'package:flutter/material.dart';

import '../../../inbox/presentation/inbox_page.dart';
import '../controllers/live_room_state_controller.dart';

class LiveRoomInboxActionsModule {
  const LiveRoomInboxActionsModule._();

  static Future<void> openInboxSheet({
    required BuildContext context,
    required LiveRoomStateController roomStateController,
    double heightFactor = 0.50,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    roomStateController.clearInboxUnreadCount();

    return showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierLabel: 'Close room inbox',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final height = MediaQuery.sizeOf(dialogContext).height * heightFactor;

        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: Container(color: Colors.black.withValues(alpha: 0.18)),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  onVerticalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity > 320) Navigator.of(dialogContext).pop();
                  },
                  child: Container(
                    height: height,
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                    ),
                    child: const InboxPage(openPagesInOverlay: true),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static void openInboxSheetAfterClosingCurrentSheet({
    required BuildContext pageContext,
    required BuildContext sheetContext,
    required LiveRoomStateController roomStateController,
  }) {
    Navigator.pop(sheetContext);
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!pageContext.mounted) return;
      openInboxSheet(
        context: pageContext,
        roomStateController: roomStateController,
      );
    });
  }
}
