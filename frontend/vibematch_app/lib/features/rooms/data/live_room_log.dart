import 'package:flutter/foundation.dart';

/// Logging policy for live-room signaling/media.
///
/// Normal room operation is intentionally quiet. High-volume traces (snapshots,
/// RTP payloads, transport state churn, identity reseeding, lifecycle chatter)
/// are available only when explicitly enabled:
///
///   --dart-define=VM_MEDIA_VERBOSE_LOGS=true
///
/// Actionable warnings/errors remain visible in debug/profile development
/// builds, while release builds stay quiet.
abstract final class LiveRoomLog {
  static const bool verbose = bool.fromEnvironment(
    'VM_MEDIA_VERBOSE_LOGS',
    defaultValue: false,
  );

  static void trace(String scope, String message) {
    if (!kDebugMode || !verbose) return;
    debugPrint('[VibeMatch$scope] $message');
  }

  static void warning(String scope, String message) {
    if (!kDebugMode) return;
    debugPrint('[VibeMatch$scope][warn] $message');
  }
}
