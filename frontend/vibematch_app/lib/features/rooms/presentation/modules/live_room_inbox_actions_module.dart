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

    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height * heightFactor;

        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: height,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: const InboxPage(openPagesInOverlay: true),
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
