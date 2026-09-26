import '../../../../foundation/runtime/media_resource_lifecycle.dart';
import 'ott_web_playback_host.dart';

/// Chunk 34-M8 lifecycle adapter for one embedded OTT Watch Party WebView.
///
/// Canonical Watch Party state remains in WatchPartyRepository/backend. This
/// adapter only coordinates local WebView cost with app/session lifecycle.
class WatchPartyWebViewResourceParticipant
    implements MediaResourceParticipant {
  WatchPartyWebViewResourceParticipant({
    required this.resourceId,
    required OttWebPlaybackHost host,
  }) : _host = host;

  @override
  final String resourceId;

  final OttWebPlaybackHost _host;
  bool _released = false;

  @override
  MediaResourceKind get kind => MediaResourceKind.watchPartyWebView;

  /// Backgrounding best-effort pauses local embedded playback. Foreground does
  /// not force play; canonical Watch Party reconciliation decides that.
  @override
  Future<void> onForegroundChanged(bool isForeground) async {
    if (_released || isForeground) return;
    try {
      await _host.pause();
    } catch (_) {
      // A provider may not have a usable player/controller yet. Capability
      // probing and the canonical coordinator handle that state separately.
    }
  }

  /// Do not destroy/reload an active provider WebView on memory pressure; doing
  /// so can interrupt provider entitlement/session playback. Future provider-
  /// safe trimming may be added behind this same lifecycle boundary.
  @override
  Future<void> onMemoryPressure() async {}

  /// Authenticated-session teardown is terminal for this registration.
  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _host.dispose();
  }
}
