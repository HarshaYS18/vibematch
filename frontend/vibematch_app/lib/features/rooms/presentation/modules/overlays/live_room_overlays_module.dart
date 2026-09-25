import 'package:flutter/widgets.dart';

import '../../widgets/live_room_overlay_host.dart';
import '../../widgets/room_seats.dart';
import '../lifecycle/live_room_lifecycle_module.dart';
import '../live_room_controller_bundle.dart';
import '../seats/live_room_seats_module.dart';

class LiveRoomOverlaysModule {
  const LiveRoomOverlaysModule._();

  static void dismissRoomOverlays(LiveRoomControllerBundle bundle) {
    dismissRoomSeatActionPill();
    LiveRoomLifecycleModule.clearFocus(bundle);
  }

  static void clearVibeSyncOverlay(LiveRoomControllerBundle bundle) {
    bundle.roomStateController.setVibeSyncState(
      bundle.vibeSyncController.clearOverlay(bundle.vibeSyncState),
    );
  }

  static Widget buildOverlayHost(LiveRoomControllerBundle bundle) {
    return LiveRoomOverlayHost(
      vibeSyncState: bundle.vibeSyncState,
      onDismissVibeSync: () => clearVibeSyncOverlay(bundle),
      giftRevision: bundle.giftRevision,
      giftController: bundle.giftControllerInstance,
      roomMusicController: bundle.roomMusicController,
      luckyPacketRealtimeService: bundle.luckyPacketRealtimeService,
      roomUsers: bundle.allRoomUsers,
      pendingSeatInviteInviterName: bundle.pendingSeatInvite?.inviterName,
      pendingSeatInviteUser: bundle.pendingSeatInvite?.invitedUser,
      pendingSeatInviteIndex: bundle.pendingSeatInvite?.seatIndex,
      onRejectSeatInvite: () => LiveRoomSeatsModule.rejectSeatInvite(bundle),
      onAcceptSeatInvite: () => LiveRoomSeatsModule.acceptSeatInvite(bundle),
    );
  }
}
