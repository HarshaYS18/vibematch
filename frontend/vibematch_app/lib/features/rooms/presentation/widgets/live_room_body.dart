import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_chat.dart';
import 'room_seats.dart';
import 'room_top_bar.dart';

class LiveRoomBody extends StatelessWidget {
  const LiveRoomBody({
    super.key,
    required this.roomName,
    required this.roomId,
    required this.privacyMode,
    required this.onlineCount,
    required this.seats,
    required this.layoutId,
    required this.selectedSeatIndex,
    required this.canManageSeats,
    required this.admins,
    required this.availableAdminUsers,
    required this.onAddAdmin,
    required this.onRemoveAdmin,
    required this.messages,
    required this.canManageSeatApplications,
    required this.messageController,
    required this.messageFocusNode,
    required this.micMuted,
    required this.inboxUnreadCount,
    required this.imagesEnabled,
    required this.onBack,
    required this.onJoinTap,
    required this.onShare,
    required this.onAnnouncement,
    required this.onSettings,
    required this.onUsersTap,
    required this.onRoomRankingsTap,
    required this.onSeatTap,
    required this.onUserTap,
    required this.onInvite,
    required this.onSwitch,
    required this.onLock,
    required this.onUnlock,
    required this.onApproveSeatApplication,
    required this.onSenderTap,
    required this.onDismissOverlays,
    required this.onInboxTap,
    required this.onEmojiTap,
    required this.onSendTap,
    required this.onMicTap,
    required this.onGamesTap,
    required this.onGiftTap,
  });

  final String roomName;
  final String roomId;
  final RoomPrivacyMode privacyMode;
  final int onlineCount;
  final List<RoomSeat> seats;
  final String layoutId;
  final int? selectedSeatIndex;
  final bool canManageSeats;
  final List<SeatUser> admins;
  final List<SeatUser> availableAdminUsers;
  final ValueChanged<SeatUser> onAddAdmin;
  final ValueChanged<SeatUser> onRemoveAdmin;
  final List<ChatEntry> messages;
  final bool canManageSeatApplications;
  final TextEditingController messageController;
  final FocusNode messageFocusNode;
  final bool micMuted;
  final int inboxUnreadCount;
  final bool imagesEnabled;
  final VoidCallback onBack;
  final VoidCallback onJoinTap;
  final VoidCallback onShare;
  final VoidCallback onAnnouncement;
  final VoidCallback onSettings;
  final VoidCallback onUsersTap;
  final VoidCallback onRoomRankingsTap;
  final ValueChanged<int> onSeatTap;
  final ValueChanged<int> onUserTap;
  final ValueChanged<int> onInvite;
  final ValueChanged<int> onSwitch;
  final ValueChanged<int> onLock;
  final ValueChanged<int> onUnlock;
  final ValueChanged<ChatEntry> onApproveSeatApplication;
  final ValueChanged<ChatEntry> onSenderTap;
  final VoidCallback onDismissOverlays;
  final VoidCallback onInboxTap;
  final VoidCallback onEmojiTap;
  final VoidCallback onSendTap;
  final VoidCallback onMicTap;
  final VoidCallback onGamesTap;
  final VoidCallback onGiftTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: RoomTopBar(
              roomName: roomName,
              roomId: roomId,
              privacyMode: privacyMode,
              onlineCount: onlineCount,
              canManageAdmins: canManageSeats,
              admins: admins,
              availableAdminUsers: availableAdminUsers,
              onAddAdmin: onAddAdmin,
              onRemoveAdmin: onRemoveAdmin,
              onBack: onBack,
              onJoinTap: onJoinTap,
              onShare: onShare,
              onAnnouncement: onAnnouncement,
              onSettings: onSettings,
              onUsersTap: onUsersTap,
              onRoomRankingsTap: onRoomRankingsTap,
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: RoomSeatLayout(
              seats: seats,
              layoutId: layoutId,
              selectedSeatIndex: selectedSeatIndex,
              canManageSeats: canManageSeats,
              onSeatTap: onSeatTap,
              onUserTap: onUserTap,
              onInvite: onInvite,
              onSwitch: onSwitch,
              onLock: onLock,
              onUnlock: onUnlock,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onDismissOverlays,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: RoomChatFeed(
                  messages: messages,
                  canManageSeatApplications: canManageSeatApplications,
                  onApproveSeatApplication: onApproveSeatApplication,
                  onSenderTap: onSenderTap,
                ),
              ),
            ),
          ),
          RoomInputDock(
            controller: messageController,
            focusNode: messageFocusNode,
            micMuted: micMuted,
            inboxUnreadCount: inboxUnreadCount,
            imagesEnabled: imagesEnabled,
            onInboxTap: onInboxTap,
            onEmojiTap: onEmojiTap,
            onSendTap: onSendTap,
            onMicTap: onMicTap,
            onGamesTap: onGamesTap,
            onGiftTap: onGiftTap,
          ),
        ],
      ),
    );
  }
}
