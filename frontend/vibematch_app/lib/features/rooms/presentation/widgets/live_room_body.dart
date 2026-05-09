import 'package:flutter/material.dart';

import '../../data/live_room_media_signaling_service.dart';
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
    required this.applyOnlyModeEnabled,
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
    required this.onRoomLevelTap,
    required this.onSeatTap,
    required this.onUserTap,
    required this.onInvite,
    required this.onSwitch,
    required this.onLock,
    required this.onUnlock,
    required this.onApplySeat,
    required this.onApproveSeatApplication,
    required this.onRejectSeatApplication,
    required this.onSenderTap,
    required this.onMentionTap,
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
  final bool applyOnlyModeEnabled;
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
  final VoidCallback onRoomLevelTap;
  final ValueChanged<int> onSeatTap;
  final ValueChanged<int> onUserTap;
  final ValueChanged<int> onInvite;
  final ValueChanged<int> onSwitch;
  final ValueChanged<int> onLock;
  final ValueChanged<int> onUnlock;
  final ValueChanged<int> onApplySeat;
  final ValueChanged<ChatEntry> onApproveSeatApplication;
  final ValueChanged<ChatEntry> onRejectSeatApplication;
  final ValueChanged<ChatEntry> onSenderTap;
  final ValueChanged<String> onMentionTap;
  final VoidCallback onDismissOverlays;
  final VoidCallback onInboxTap;
  final VoidCallback onEmojiTap;
  final VoidCallback onSendTap;
  final VoidCallback onMicTap;
  final VoidCallback onGamesTap;
  final VoidCallback onGiftTap;

  void _handleSeatTap(int index) {
    if (index >= 0 && index < seats.length) {
      final seat = seats[index];
      if (!seat.locked && seat.user == null && !applyOnlyModeEnabled) {
        LiveRoomMediaSignalingService.instance.takeSeat(index);
      }
    }
    onSeatTap(index);
  }

  void _handleSwitchSeat(int index) {
    LiveRoomMediaSignalingService.instance.takeSeat(index);
    onSwitch(index);
  }

  void _handleMicTap() {
    LiveRoomMediaSignalingService.instance.setMicEnabled(micMuted);
    onMicTap();
  }

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
              onRoomLevelTap: onRoomLevelTap,
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
              applyOnlyModeEnabled: applyOnlyModeEnabled,
              onSeatTap: _handleSeatTap,
              onUserTap: onUserTap,
              onInvite: onInvite,
              onSwitch: _handleSwitchSeat,
              onLock: onLock,
              onUnlock: onUnlock,
              onApply: onApplySeat,
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
                  onRejectSeatApplication: onRejectSeatApplication,
                  onSenderTap: onSenderTap,
                  onMentionTap: onMentionTap,
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
            onMicTap: _handleMicTap,
            onGamesTap: onGamesTap,
            onGiftTap: onGiftTap,
          ),
        ],
      ),
    );
  }
}
