import 'package:flutter/material.dart';

import '../../data/live_room_media_signaling_service.dart';
import '../live_room_models.dart';
import '../modules/cricket_room_controls_module.dart';
import '../modules/cricket_room_mode_module.dart';
import 'live_room_input_dock.dart';
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
    this.canManageAdmins = false,
    this.canEditRoomName = false,
    this.canManageAnnouncement = false,
    required this.applyOnlyModeEnabled,
    this.currentUserIsMember = false,
    this.joinRequestPending = false,
    required this.admins,
    required this.availableAdminUsers,
    required this.onAddAdmin,
    required this.onRemoveAdmin,
    required this.onRemoveRoomMember,
    required this.messages,
    required this.canManageSeatApplications,
    required this.messageController,
    required this.messageFocusNode,
    required this.micMuted,
    this.showMicButton,
    required this.inboxUnreadCount,
    required this.imagesEnabled,
    required this.cricketModeController,
    this.watchPartyModule,
    required this.onBack,
    required this.onJoinTap,
    required this.onShare,
    required this.onAnnouncement,
    required this.onEditRoomName,
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
    required this.onImageMessage,
    required this.onMicTap,
    required this.onGamesTap,
    required this.onGiftTap,
    required this.onCricketEndMatch,
    required this.onCricketStartNewMatch,
  });

  final String roomName;
  final String roomId;
  final RoomPrivacyMode privacyMode;
  final int onlineCount;
  final List<RoomSeat> seats;
  final String layoutId;
  final int? selectedSeatIndex;
  final bool canManageSeats;
  final bool canManageAdmins;
  final bool canEditRoomName;
  final bool canManageAnnouncement;
  final bool applyOnlyModeEnabled;
  final bool currentUserIsMember;
  final bool joinRequestPending;
  final List<SeatUser> admins;
  final List<SeatUser> availableAdminUsers;
  final ValueChanged<SeatUser> onAddAdmin;
  final ValueChanged<SeatUser> onRemoveAdmin;
  final ValueChanged<SeatUser> onRemoveRoomMember;
  final List<ChatEntry> messages;
  final bool canManageSeatApplications;
  final TextEditingController messageController;
  final FocusNode messageFocusNode;
  final bool micMuted;
  final bool? showMicButton;
  final int inboxUnreadCount;
  final bool imagesEnabled;
  final CricketRoomModeController cricketModeController;
  final Widget? watchPartyModule;
  final VoidCallback onBack;
  final VoidCallback onJoinTap;
  final VoidCallback onShare;
  final VoidCallback onAnnouncement;
  final VoidCallback onEditRoomName;
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
  final void Function({
    required String imageUrl,
    required String contentType,
  }) onImageMessage;
  final VoidCallback onMicTap;
  final VoidCallback onGamesTap;
  final VoidCallback onGiftTap;
  final VoidCallback onCricketEndMatch;
  final VoidCallback onCricketStartNewMatch;

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
    final activeUser =
        LiveRoomMediaSignalingService.instance.activeLoggedInSeatUser;
    if (activeUser == null) return false;
    return seats.any((seat) => seat.user?.id == activeUser.id);
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowMicButton = showMicButton ?? _derivedShowMicButton;

    return AnimatedBuilder(
      animation: cricketModeController,
      builder: (context, child) {
        final cricketController =
            cricketModeController.active ? cricketModeController : null;
        final cricketModeActive = cricketController != null;
        final effectiveSeats = cricketModeActive ? _cricketSeats() : seats;
        final activeUser =
            LiveRoomMediaSignalingService.instance.activeLoggedInSeatUser;
        final canManageCricket =
            cricketModeActive &&
            cricketController != null &&
            activeUser != null &&
            CricketRoomModeModule.canScore(
              seats: effectiveSeats,
              currentUserId: activeUser.id,
            );
        final effectiveLayoutId = cricketModeActive
            ? CricketRoomRules.fixedLayoutId
            : layoutId;
        final effectiveSelectedSeatIndex =
            cricketModeActive &&
                selectedSeatIndex != null &&
                selectedSeatIndex! >= CricketRoomRules.totalSeats
            ? null
            : selectedSeatIndex;

        return SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: RoomTopBar(
                      roomName: roomName,
                      roomId: roomId,
                      privacyMode: privacyMode,
                      onlineCount: _effectiveOnlineCount,
                      canManageRoom: canManageSeats,
                      canManageAdmins: canManageAdmins,
                      canEditRoomName: canEditRoomName,
                      canManageAnnouncement: canManageAnnouncement,
                      currentUserIsMember: currentUserIsMember,
                      joinRequestPending: joinRequestPending,
                      admins: admins,
                      availableAdminUsers: availableAdminUsers,
                      onAddAdmin: onAddAdmin,
                      onRemoveAdmin: onRemoveAdmin,
                      onRemoveRoomMember: onRemoveRoomMember,
                      onBack: onBack,
                      onJoinTap: onJoinTap,
                      onShare: onShare,
                      onAnnouncement: onAnnouncement,
                      onEditRoomName: onEditRoomName,
                      onSettings: onSettings,
                      onUsersTap: onUsersTap,
                      onRoomRankingsTap: onRoomRankingsTap,
                      onRoomLevelTap: onRoomLevelTap,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: RoomSeatLayout(
                      seats: effectiveSeats,
                      layoutId: effectiveLayoutId,
                      selectedSeatIndex: effectiveSelectedSeatIndex,
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
                  if (watchPartyModule != null) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: watchPartyModule!,
                    ),
                  ],
                  const SizedBox(height: 3),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: onDismissOverlays,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                        child: Column(
                          children: [
                            if (cricketModeActive)
                              AnimatedBuilder(
                                animation: cricketController!,
                                builder: (context, child) =>
                                    CricketRoomModeModule.fixedScoreboard(
                                      state: cricketController.match,
                                      margin: const EdgeInsets.only(bottom: 6),
                                    ),
                              ),
                            Expanded(
                              child: RoomChatFeed(
                                messages: messages,
                                canManageSeatApplications:
                                    canManageSeatApplications,
                                onApproveSeatApplication:
                                    onApproveSeatApplication,
                                onRejectSeatApplication:
                                    onRejectSeatApplication,
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
                    onImageMessage: onImageMessage,
                    onMicTap: onMicTap,
                    onGamesTap: onGamesTap,
                    onGiftTap: onGiftTap,
                  ),
                ],
              ),
              if (cricketModeActive)
                AnimatedBuilder(
                  animation: cricketController!,
                  builder: (context, child) {
                    return CricketRoomControlsModule(
                      controller: cricketController,
                      canManage: canManageCricket,
                      onEndMode: onCricketEndMatch,
                      onStartNewMatch: onCricketStartNewMatch,
                    );
                  },
                ),
              if (cricketModeActive && canManageCricket)
                AnimatedBuilder(
                  animation: cricketController,
                  builder: (context, child) {
                    return CricketRoomModeModule.scorerOverlay(
                      controller: cricketController,
                      visibleToCurrentUser: true,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  List<RoomSeat> _cricketSeats() {
    final visibleSeats = seats
        .take(CricketRoomRules.totalSeats)
        .toList(growable: true);
    for (
      var index = visibleSeats.length;
      index < CricketRoomRules.totalSeats;
      index++
    ) {
      visibleSeats.add(RoomSeat(index: index));
    }
    return visibleSeats;
  }
}
