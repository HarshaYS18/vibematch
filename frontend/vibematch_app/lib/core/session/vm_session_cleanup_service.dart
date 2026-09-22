import 'dart:async';

import '../../features/rooms/data/active_room_context.dart';
import '../../features/rooms/data/live_room_media_signaling_service.dart';
import '../../features/rooms/data/live_room_member_request_service.dart';
import '../../features/rooms/data/live_room_membership_service.dart';
import '../../features/rooms/data/live_room_presence_repository.dart';
import '../../features/rooms/data/room_music_controller.dart';
import '../../features/rooms/presentation/widgets/live_room_minimized_overlay_service.dart';
import '../../features/vibes/presentation/widgets/vibe_media_playback_gate.dart';
import '../../features/wallet/data/wallet_realtime_sync_service.dart';

class VmSessionCleanupService {
  const VmSessionCleanupService._();

  static Future<void> clearUserScopedState({String reason = 'auth session changed'}) async {
    LiveRoomMinimizedOverlayService.hide();
    VibeMediaPlaybackGate.feedPlaybackPaused.value = true;

    // These are process-local projections only. Never let room/user state from
    // one authenticated account bleed into the next account.
    ActiveRoomContext.clear();
    LiveRoomMemberRequestService.instance.stop();
    LiveRoomPresenceRepository.clearCachedPresence();
    LiveRoomMembershipService.clearAll();

    await Future.wait<void>([
      LiveRoomMediaSignalingService.instance.leaveRoom(),
      RoomMusicController.instance.stopBecauseControllerExitedRoom(),
      WalletRealtimeSyncService.instance.stop(),
    ]);
  }

  static void clearUserScopedStateUnawaited({String reason = 'auth session changed'}) {
    unawaited(clearUserScopedState(reason: reason));
  }
}
