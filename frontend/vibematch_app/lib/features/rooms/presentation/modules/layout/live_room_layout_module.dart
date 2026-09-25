import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../session/data/session_repository.dart';
import '../../../../../watch_party/data/watch_party_repository.dart';
import '../../widgets/live_room_body.dart';
import '../../widgets/live_room_minimized_bubble.dart';
import '../../widgets/live_room_shell.dart';
import '../../widgets/room_seats.dart';
import '../chat/live_room_chat_module.dart';
import '../cricket/live_room_cricket_module.dart';
import '../games/live_room_games_entry_module.dart';
import '../gifts/live_room_gifts_module.dart';
import '../header/live_room_header_module.dart';
import '../lifecycle/live_room_lifecycle_module.dart';
import '../live_room_controller_bundle.dart';
import '../live_room_watch_party_module.dart';
import '../overlays/live_room_overlays_module.dart';
import '../profile/live_room_profile_module.dart';
import '../seats/live_room_seats_module.dart';
import '../settings/live_room_settings_module.dart';
import '../watch_party/live_room_watch_party_entry_module.dart';

/// Composes the visible live-room route from one scoped controller bundle.
///
/// Durable room state remains in RoomSessionRepository. Room-scoped
/// presentation controllers are supplied through LiveRoomControllerBundle;
/// this module owns no global room state.
class LiveRoomLayoutModule extends ConsumerWidget {
  const LiveRoomLayoutModule({super.key, required this.bundle});

  final LiveRoomControllerBundle bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchPartyState = ref.watch(
      watchPartyRepositoryProvider(bundle.roomId),
    );
    final signedInUserId = ref.watch(
      sessionRepositoryProvider.select((state) => state.signedInUserId),
    );
    final session = watchPartyState.session;
    final canControlWatchParty =
        bundle.viewerCanManageRoom ||
        (session != null &&
            signedInUserId != null &&
            session.controllerUserId == signedInUserId);

    final watchPartyModule = watchPartyState.active
        ? LiveRoomWatchPartyModule(
            active: true,
            canManage: canControlWatchParty,
            onOpenSettings: () =>
                LiveRoomWatchPartyEntryModule.openFromRoom(bundle: bundle),
            onEndWatchParty: () => unawaited(_endWatchParty(ref)),
          )
        : null;

    return ValueListenableBuilder<int>(
      valueListenable: bundle.roomRevision,
      builder: (context, value, child) =>
          _buildRoomRoute(context, watchPartyModule),
    );
  }

  Future<void> _endWatchParty(WidgetRef ref) async {
    try {
      await ref.read(watchPartyRepositoryProvider(bundle.roomId).notifier).end();
    } catch (_) {
      // The functional Watch Party sheet exposes command errors and retry UI.
    }
  }

  Widget _buildRoomRoute(
    BuildContext context,
    Widget? watchPartyModule,
  ) {
    if (bundle.minimized) {
      return PopScope<void>(
        canPop: bundle.allowRoomPop,
        onPopInvokedWithResult: (didPop, result) {
          LiveRoomLifecycleModule.handleRoomPop(bundle: bundle, didPop: didPop);
        },
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(ignoring: true, child: SizedBox.expand()),
            ),
            LiveRoomMinimizedBubble(
              offset: bundle.bubbleOffset,
              onRestore: () {
                dismissRoomSeatActionPill();
                bundle.roomStateController.setMinimized(false);
              },
              onDrag: (details) {
                dismissRoomSeatActionPill();
                bundle.roomStateController.moveBubble(
                  delta: details.delta,
                  screenSize: MediaQuery.sizeOf(context),
                );
              },
            ),
          ],
        ),
      );
    }

    return LiveRoomShell(
      canPop: bundle.allowRoomPop,
      onPopInvokedWithResult: (didPop, result) {
        LiveRoomLifecycleModule.handleRoomPop(bundle: bundle, didPop: didPop);
      },
      backgroundTheme: bundle.selectedBackgroundTheme,
      onDismissOverlays: () =>
          LiveRoomOverlaysModule.dismissRoomOverlays(bundle),
      children: [
        LiveRoomBody(
          roomName: bundle.roomName,
          roomId: bundle.roomId,
          privacyMode: bundle.privacyMode,
          onlineCount: bundle.safeOnlineCount,
          seats: bundle.seatController.seats,
          layoutId: bundle.seatController.layoutId,
          selectedSeatIndex: bundle.seatController.selectedSeatIndex,
          canManageSeats: bundle.viewerCanManageRoom,
          canManageAdmins: bundle.viewerCanManageAdmins,
          canEditRoomName: bundle.viewerCanManageAdmins,
          canManageAnnouncement: bundle.viewerCanManageAdmins,
          applyOnlyModeEnabled: bundle.applyOnlyModeEnabled,
          currentUserIsMember: bundle.currentUserIsMember,
          joinRequestPending: bundle.joinRequestPending,
          admins: bundle.roomAdmins,
          availableAdminUsers: bundle.availableAdminUsers,
          onAddAdmin: (user) =>
              LiveRoomProfileModule.addRoomAdminFromInfo(bundle, user),
          onRemoveAdmin: (user) =>
              LiveRoomProfileModule.removeRoomAdminFromInfo(bundle, user),
          onRemoveRoomMember: (user) =>
              LiveRoomProfileModule.removeRoomMemberFromInfo(bundle, user),
          messages: bundle.roomMessageController.messages,
          canManageSeatApplications: bundle.viewerCanManageRoom,
          messageController: bundle.messageController,
          messageFocusNode: bundle.messageFocusNode,
          micMuted: bundle.seatController.micMuted,
          showMicButton: bundle.currentUserIsSeated,
          inboxUnreadCount: bundle.inboxUnreadCount,
          imagesEnabled: bundle.roomImagesEnabled,
          cricketModeController: bundle.cricketModeController,
          watchPartyModule: watchPartyModule,
          onBack: () => LiveRoomLifecycleModule.openLeaveSheet(bundle),
          onJoinTap: () => LiveRoomSeatsModule.handleJoinRoom(bundle),
          onShare: () => LiveRoomChatModule.openRoomShareSheet(bundle),
          onAnnouncement: () =>
              LiveRoomSettingsModule.openAnnouncementSheet(bundle),
          onEditRoomName: () =>
              LiveRoomHeaderModule.openEditRoomNameSheet(bundle),
          onSettings: () => LiveRoomSettingsModule.open(bundle),
          onUsersTap: () => LiveRoomHeaderModule.openRoomUsersSheet(bundle),
          onRoomRankingsTap: () =>
              LiveRoomHeaderModule.openRoomRankingsSheet(bundle),
          onRoomLevelTap: () => LiveRoomHeaderModule.openRoomLevelPage(bundle),
          onSeatTap: (index) => LiveRoomSeatsModule.onSeatTap(bundle, index),
          onUserTap: (index) => LiveRoomSeatsModule.onUserTap(bundle, index),
          onInvite: (index) => LiveRoomSeatsModule.inviteSeat(bundle, index),
          onSwitch: bundle.seatController.switchSeat,
          onLock: bundle.seatController.lockSeat,
          onUnlock: bundle.seatController.unlockSeat,
          onApplySeat: (index) =>
              LiveRoomSeatsModule.applyForSeat(bundle, index),
          onApproveSeatApplication: (entry) =>
              LiveRoomSeatsModule.approveSeatApplication(bundle, entry),
          onRejectSeatApplication: (entry) =>
              LiveRoomSeatsModule.rejectSeatApplication(bundle, entry),
          onSenderTap: (entry) =>
              LiveRoomProfileModule.openMiniProfileFromChat(bundle, entry),
          onMentionTap: (mention) =>
              LiveRoomProfileModule.openMentionedUserProfile(bundle, mention),
          onDismissOverlays: () =>
              LiveRoomOverlaysModule.dismissRoomOverlays(bundle),
          onInboxTap: () => LiveRoomChatModule.openInboxPage(bundle),
          onEmojiTap: () => LiveRoomChatModule.openEmojiTray(bundle),
          onSendTap: () => LiveRoomChatModule.sendMessage(bundle),
          onImageMessage: bundle.roomMessageController.sendImageMessage,
          onMicTap: () => LiveRoomChatModule.toggleMic(bundle),
          onGamesTap: () => LiveRoomGamesEntryModule.openGamesSheet(bundle),
          onGiftTap: () => LiveRoomGiftsModule.openGiftPanel(bundle),
          onCricketEndMatch: () => LiveRoomCricketModule.endMatch(bundle),
          onCricketStartNewMatch: () =>
              LiveRoomCricketModule.startNewMatch(bundle),
        ),
        LiveRoomOverlaysModule.buildOverlayHost(bundle),
      ],
    );
  }
}
