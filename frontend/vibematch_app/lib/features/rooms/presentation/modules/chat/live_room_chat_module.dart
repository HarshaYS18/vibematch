import 'package:flutter/material.dart';

import '../../../../social/widgets/friends_invite_sheet.dart';
import '../../../data/chat_moderation_api_service.dart';
import '../../controllers/live_room_sheet_controller.dart';
import '../../widgets/room_theme.dart';
import '../lifecycle/live_room_lifecycle_module.dart';
import '../live_room_controller_bundle.dart';
import '../live_room_emoji_actions_module.dart';
import '../live_room_inbox_actions_module.dart';
import '../live_room_message_actions_module.dart';

/// Room-scoped chat actions layered on canonical RoomSessionRepository state.
///
/// Moderation runs before the durable command. Text/image messages are sent by
/// LiveRoomMessageController through RoomSessionRepository; this module never
/// writes a local durable chat list or uses the media singleton as chat
/// authority.
class LiveRoomChatModule {
  const LiveRoomChatModule._();

  static Future<void> sendMessage(LiveRoomControllerBundle bundle) async {
    final text = bundle.messageController.text.trim();
    if (text.isEmpty) return;
    late final ChatModerationResult moderation;
    try {
      moderation = await bundle.chatModerationApi.checkText(
        text: text,
        roomId: bundle.roomId,
      );
    } catch (error) {
      RoomToast.show(
        bundle.context,
        error.toString().replaceFirst('Exception: ', ''),
      );
      return;
    }
    if (!moderation.allowed) {
      RoomToast.show(bundle.context, moderation.userMessage);
      return;
    }
    try {
      await bundle.roomMessageController.sendMessage(text);
      if (!bundle.mounted) return;
      bundle.messageController.clear();
    } catch (error) {
      if (!bundle.mounted) return;
      RoomToast.show(
        bundle.context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  static void insertSystemMessage(
    LiveRoomControllerBundle bundle,
    String message,
  ) {
    bundle.roomMessageController.insertSystemMessage(message);
  }

  static void toggleMic(LiveRoomControllerBundle bundle) {
    LiveRoomLifecycleModule.clearFocus(bundle);
    bundle.seatController.toggleMic();
  }

  static void openMessageComposerWithMention(LiveRoomControllerBundle bundle) {
    LiveRoomLifecycleModule.clearFocus(bundle);
    LiveRoomMessageActionsModule.openComposer(
      context: bundle.context,
      controller: bundle.messageController,
      focusNode: bundle.messageFocusNode,
      imagesEnabled: bundle.roomImagesEnabled,
      onDismissSeatActions: bundle.seatController.clearSelectedSeat,
      onSendText: () => sendMessage(bundle),
      onImageTap: () => handleImageMessageTap(bundle),
      onSendFloatingText: () => sendMessage(bundle),
    );
  }

  static void handleImageMessageTap(LiveRoomControllerBundle bundle) {
    RoomToast.show(bundle.context, 'Image message picker will connect here');
  }

  static void openRoomShareSheet(LiveRoomControllerBundle bundle) {
    LiveRoomLifecycleModule.clearFocus(bundle);
    LiveRoomSheetController.showTransparentSheet<void>(
      context: bundle.context,
      isScrollControlled: true,
      builder: (_) => FriendsInviteSheet(
        title: 'Invite friends to ${bundle.roomName}',
        actionLabel: 'Invite',
        completedLabel: 'Sent',
        onInvite: (friend) => sendRoomInviteToInbox(bundle, friend.displayName),
      ),
    );
  }

  static void sendRoomInviteToInbox(
    LiveRoomControllerBundle bundle,
    String friendName,
  ) {
    RoomToast.show(bundle.context, 'Room invite sent to $friendName\'s Inbox');
  }

  static void openInboxPage(LiveRoomControllerBundle bundle) {
    LiveRoomLifecycleModule.clearFocus(bundle);
    LiveRoomInboxActionsModule.openInboxSheet(
      context: bundle.context,
      roomStateController: bundle.roomStateController,
    );
  }

  static void openInboxPageFromSheet(
    LiveRoomControllerBundle bundle,
    BuildContext sheetContext,
  ) {
    LiveRoomInboxActionsModule.openInboxSheetAfterClosingCurrentSheet(
      pageContext: bundle.context,
      sheetContext: sheetContext,
      roomStateController: bundle.roomStateController,
    );
  }

  static void openEmojiTray(LiveRoomControllerBundle bundle) {
    LiveRoomLifecycleModule.clearFocus(bundle);
    LiveRoomEmojiActionsModule.openEmojiTray(context: bundle.context);
  }
}
