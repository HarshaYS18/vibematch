import 'package:flutter/material.dart';

import '../../data/live_room_media_signaling_service.dart';
import '../live_room_models.dart';
import '../modules/cricket_room_controls_module.dart';
import '../modules/cricket_room_mode_module.dart';
import '../modules/cricket_room_mode_registry.dart';
import '../modules/cricket_room_mode_signal.dart';
import 'live_room_input_dock.dart';
import 'live_room_seat_invite_notification.dart';
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
    this.currentUserIsMember = false,
    this.joinRequestPending = false,
    required this.admins,
    required this.availableAdminUsers,
    required this.onAddAdmin,
    required this.onRemoveAdmin,
    required this.messages,
    required this.canManageSeatApplications,
    required this.messageController,
    required this.messageFocusNode,
    required this.micMuted,
    this.showMicButton,
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
  final bool currentUserIsMember;
  final bool joinRequestPending;
  final List<SeatUser> admins;
  final List<SeatUser> availableAdminUsers;
  final ValueChanged<SeatUser> onAddAdmin;
  final ValueChanged<SeatUser> onRemoveAdmin;
  final List<ChatEntry> messages;
  final bool canManageSeatApplications;
  final TextEditingController messageController;
  final FocusNode messageFocusNode;
  final bool micMuted;
  final bool? showMicButton;
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

  int get _effectiveOnlineCount {
    final ids = <String>{};
    for (final user in admins) {
      if (user.id.trim().isNotEmpty) ids.add(user.id);
    }
    for (final user in availableAdminUsers) {
      if (user.id.trim().isNotEmpty) ids.add(user.id);
    }
    return ids.length > onlineCount ? ids.length : onlineCount;
  }

  bool get _derivedShowMicButton {
    final activeUser = LiveRoomMediaSignalingService.instance.activeLoggedInSeatUser;
    if (activeUser == null) return false;
    return seats.any((seat) => seat.user?.id == activeUser.id);
  }

  @override
  Widget build(BuildContext context) {
    final media = LiveRoomMediaSignalingService.instance;
    final shouldShowMicButton = showMicButton ?? _derivedShowMicButton;

    return ValueListenableBuilder<Set<String>>(
      valueListenable: CricketRoomModeSignal.activeRoomIds,
      builder: (context, activeRoomIds, child) {
        final cricketController = CricketRoomModeRegistry.syncRoomModeFromSignal(
          roomId: roomId,
          roomName: roomName,
          currentLayoutId: layoutId,
        );
        final cricketModeActive = cricketController.active;
        final currentUser = media.activeLoggedInSeatUser;
        final scorerVisible = cricketModeActive &&
            currentUser != null &&
            CricketRoomModeModule.canScore(
              seats: seats,
              currentUserId: currentUser.id,
            );
        final effectiveLayoutId = cricketModeActive ? CricketRoomRules.fixedLayoutId : layoutId;
        return SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: RoomTopBar(
                      roomName: roomName,
                      roomId: roomId,
                      privacyMode: privacyMode,
                      onlineCount: _effectiveOnlineCount,
                      canManageAdmins: canManageSeats,
                      currentUserIsMember: currentUserIsMember,
                      joinRequestPending: joinRequestPending,
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
                      layoutId: effectiveLayoutId,
                      selectedSeatIndex: selectedSeatIndex,
                      canManageSeats: canManageSeats,
                      applyOnlyModeEnabled: applyOnlyModeEnabled,
                      onSeatTap: onSeatTap,
                      onUserTap: onUserTap,
                      onInvite: onInvite,
                      onSwitch: onSwitch,
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
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                        child: Column(
                          children: [
                            if (cricketModeActive)
                              AnimatedBuilder(
                                animation: cricketController,
                                builder: (context, child) {
                                  return CricketRoomModeModule.fixedScoreboard(
                                    state: cricketController.match,
                                    margin: const EdgeInsets.only(bottom: 8),
                                  );
                                },
                              ),
                            Expanded(
                              child: RoomChatFeed(
                                messages: messages,
                                canManageSeatApplications: canManageSeatApplications,
                                onApproveSeatApplication: onApproveSeatApplication,
                                onRejectSeatApplication: onRejectSeatApplication,
                                onSenderTap: onSenderTap,
                                onMentionTap: onMentionTap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  RoomInputDock(
                    controller: messageController,
                    focusNode: messageFocusNode,
                    micMuted: micMuted,
                    showMicButton: shouldShowMicButton,
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
              if (cricketModeActive)
                AnimatedBuilder(
                  animation: cricketController,
                  builder: (context, child) {
                    return CricketRoomControlsModule(
                      controller: cricketController,
                      canManage: scorerVisible,
                      onEndMode: onDismissOverlays,
                    );
                  },
                ),
              if (cricketModeActive)
                AnimatedBuilder(
                  animation: cricketController,
                  builder: (context, child) {
                    return CricketRoomModeModule.scorerOverlay(
                      controller: cricketController,
                      visibleToCurrentUser: scorerVisible,
                    );
                  },
                ),
              ValueListenableBuilder<LiveMediaSeatInvite?>(
                valueListenable: media.seatInvite,
                builder: (context, invite, child) {
                  if (invite == null || invite.seatIndex < 0) return const SizedBox.shrink();
                  final currentUser = media.activeLoggedInSeatUser;
                  if (currentUser == null) return const SizedBox.shrink();
                  return Positioned.fill(
                    child: IgnorePointer(
                      ignoring: false,
                      child: Center(
                        child: LiveRoomSeatInviteNotification(
                          inviterName: invite.inviterName,
                          invitedUser: currentUser,
                          seatIndex: invite.seatIndex,
                          onReject: media.clearSeatInvite,
                          onAccept: () {
                            media.takeSeat(invite.seatIndex);
                            media.clearSeatInvite();
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
