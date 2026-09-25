import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/lucky_packet_realtime_service.dart';
import '../../data/room_music_controller.dart';
import '../controllers/live_room_gift_controller.dart';
import '../live_room_models.dart';
import '../modules/room_music_overlay.dart';
import 'live_room_gift_overlay.dart';
import 'live_room_remote_audio_renderers.dart';
import 'live_room_seat_invite_notification.dart';
import 'lucky_win_celebration_overlay.dart';
import 'vibesync_room_module.dart';

/// Hosts overlays for a single mounted room controller bundle.
///
/// Gift presentation queues are obtained from the scoped
/// [LiveRoomGiftController]; this host never creates or reads process-global
/// room presentation state.
class LiveRoomOverlayHost extends StatelessWidget {
  const LiveRoomOverlayHost({
    super.key,
    required this.vibeSyncState,
    required this.onDismissVibeSync,
    required this.giftRevision,
    required this.giftController,
    required this.roomMusicController,
    required this.luckyPacketRealtimeService,
    required this.roomUsers,
    required this.pendingSeatInviteInviterName,
    required this.pendingSeatInviteUser,
    required this.pendingSeatInviteIndex,
    required this.onRejectSeatInvite,
    required this.onAcceptSeatInvite,
  });

  final VibeSyncRoomState vibeSyncState;
  final VoidCallback onDismissVibeSync;
  final ValueListenable<int> giftRevision;
  final LiveRoomGiftController? giftController;
  final RoomMusicController roomMusicController;
  final LuckyPacketRealtimeService luckyPacketRealtimeService;
  final List<SeatUser> roomUsers;
  final String? pendingSeatInviteInviterName;
  final SeatUser? pendingSeatInviteUser;
  final int? pendingSeatInviteIndex;
  final VoidCallback onRejectSeatInvite;
  final VoidCallback onAcceptSeatInvite;

  bool get _hasPendingSeatInvite {
    return pendingSeatInviteInviterName != null &&
        pendingSeatInviteUser != null &&
        pendingSeatInviteIndex != null;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        VibeSyncRoomOverlay(state: vibeSyncState, onDismiss: onDismissVibeSync),
        const LiveRoomRemoteAudioRenderers(),
        RoomMusicOverlayHost(controller: roomMusicController),
        ValueListenableBuilder<int>(
          valueListenable: giftRevision,
          builder: (context, value, child) {
            final controller = giftController;
            if (controller == null) return const SizedBox.shrink();
            return LiveRoomGiftOverlay(
              slides: controller.giftSlides,
              activeComboSlide: controller.activeComboSlide,
              activeLuckyPacket: controller.activeLuckyPacket,
              bottomPadding: MediaQuery.paddingOf(context).bottom,
              onComboTap: (slide) => controller.tapGiftCombo(slide),
              onVideoGiftFinished: (slide) =>
                  controller.finishVideoGift(slide),
              onComboButtonTap: () {
                final slide = controller.activeComboSlide;
                if (slide != null) controller.tapGiftCombo(slide);
              },
              onLuckyPacketGetTap: () =>
                  unawaited(luckyPacketRealtimeService.claim()),
              onLuckyPacketResultsDismiss:
                  luckyPacketRealtimeService.dismiss,
              currentUserId: controller.currentUser.id,
              giftFlightBus: controller.giftFlightBus,
              premiumGiftBroadcastBus: controller.premiumGiftBroadcastBus,
            );
          },
        ),
        // Authoritative lucky gift results are celebrated independently from
        // the combo slide state. This keeps x100/x500/x1000 effects room-wide
        // without feeding visual state back into combo accounting.
        const LuckyWinCelebrationOverlay(),
        if (_hasPendingSeatInvite)
          LiveRoomSeatInviteNotification(
            inviterName: pendingSeatInviteInviterName!,
            invitedUser: pendingSeatInviteUser!,
            seatIndex: pendingSeatInviteIndex!,
            onReject: onRejectSeatInvite,
            onAccept: onAcceptSeatInvite,
          ),
      ],
    );
  }
}
