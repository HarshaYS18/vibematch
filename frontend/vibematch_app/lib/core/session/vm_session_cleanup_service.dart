import 'dart:async';

import '../../features/rooms/data/live_room_media_signaling_service.dart';
import '../../features/rooms/presentation/widgets/live_room_minimized_overlay_service.dart';
import '../../features/wallet/data/wallet_realtime_sync_service.dart';

/// Clears process-local session resources when authentication changes.
///
/// Durable room identity/state is not owned here. RoomSessionRepository is
/// scoped/disposed by the room lifecycle; this service only detaches transport,
/// overlays and user-scoped realtime projections.
class VmSessionCleanupService {
  const VmSessionCleanupService._();

  static Future<void> clearUserScopedState({String reason = 'auth session changed'}) async {
    LiveRoomMinimizedOverlayService.hide();

    // These are process-local projections only. Never let room/user state from
    // one authenticated account bleed into the next account.
    await Future.wait<void>([
      LiveRoomMediaSignalingService.instance.leaveRoom(),
      WalletRealtimeSyncService.instance.stop(),
    ]);
  }

  static void clearUserScopedStateUnawaited({String reason = 'auth session changed'}) {
    unawaited(clearUserScopedState(reason: reason));
  }
}
