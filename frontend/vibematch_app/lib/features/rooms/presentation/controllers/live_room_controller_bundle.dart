import 'package:flutter/material.dart';

import '../../data/room_moderation_repository.dart';
import '../live_room_models.dart';
import 'live_room_gift_controller.dart';
import 'live_room_message_controller.dart';
import 'live_room_mention_text_controller.dart';
import 'live_room_moderation_controller.dart';
import 'live_room_navigation_controller.dart';
import 'live_room_seat_controller.dart';
import 'live_room_settings_controller.dart';
import 'live_room_state_controller.dart';
import 'live_room_users_controller.dart';
import 'live_room_vibesync_controller.dart';

class LiveRoomControllerBundle {
  LiveRoomControllerBundle({
    required this.roomName,
    required this.roomId,
    required this.modeTitle,
    required this.onlineCount,
    required this.currentUser,
    required VoidCallback onUiChanged,
    required ValueChanged<ChatEntry> onFinalGiftMessage,
    required ValueChanged<String> onToast,
  })  : messageController = LiveRoomMentionTextController(),
        announcementController = TextEditingController(),
        messageFocusNode = FocusNode(),
        stateController = LiveRoomStateController(
          initialRoomName: roomName,
          initialRoomId: roomId,
          initialModeTitle: modeTitle,
        ),
        moderationController = LiveRoomModerationController(currentUser: currentUser),
        roomMessageController = LiveRoomMessageController(
          currentUser: currentUser,
          onChanged: onUiChanged,
        ),
        seatController = LiveRoomSeatController(
          currentUser: currentUser,
          onChanged: onUiChanged,
          onToast: onToast,
        ),
        giftController = LiveRoomGiftController(
          currentUser: currentUser,
          onChanged: onUiChanged,
          onFinalGiftMessage: onFinalGiftMessage,
          onToast: onToast,
        ) {
    seatController.initialize('5x2');
    if (seatController.roomUsers.isNotEmpty) {
      giftController.selectedReceiverIds.add(seatController.roomUsers.first.id);
    }
  }

  final String roomName;
  final String roomId;
  final String modeTitle;
  final int onlineCount;
  final SeatUser currentUser;

  final LiveRoomMentionTextController messageController;
  final TextEditingController announcementController;
  final FocusNode messageFocusNode;
  final LiveRoomStateController stateController;
  final LiveRoomGiftController giftController;
  final LiveRoomSeatController seatController;
  final LiveRoomMessageController roomMessageController;
  final LiveRoomModerationController moderationController;

  final LiveRoomUsersController usersController = const LiveRoomUsersController();
  final LiveRoomSettingsController settingsController = const LiveRoomSettingsController();
  final LiveRoomVibeSyncController vibeSyncController = const LiveRoomVibeSyncController();
  final LiveRoomNavigationController navigationController = const LiveRoomNavigationController();

  void dispose() {
    messageController.dispose();
    announcementController.dispose();
    messageFocusNode.dispose();
    giftController.dispose();
    moderationController.dispose();
    stateController.dispose();
  }
}
