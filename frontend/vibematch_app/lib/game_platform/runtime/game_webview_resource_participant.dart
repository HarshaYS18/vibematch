import '../../foundation/runtime/media_resource_lifecycle.dart';
import 'game_runtime.dart';

/// Lifecycle adapter for one feature-owned remote game WebView runtime.
///
/// This adapter coordinates runtime cost only. It does not own durable game
/// sessions, rounds, bets, settlement or Host Bridge authorization.
class GameWebViewResourceParticipant implements MediaResourceParticipant {
  GameWebViewResourceParticipant({
    required this.resourceId,
    required GameRuntime runtime,
  }) : _runtime = runtime;

  @override
  final String resourceId;

  final GameRuntime _runtime;
  bool _released = false;

  @override
  MediaResourceKind get kind => MediaResourceKind.gameWebView;

  /// Gives verified remote game HTML a chance to pause/resume presentation
  /// work without changing any authoritative game state.
  @override
  Future<void> onForegroundChanged(bool isForeground) async {
    if (_released) return;
    await _runtime.sendHostEvent(
      'app.lifecycle',
      payload: <String, dynamic>{'foreground': isForeground},
    );
  }

  /// Memory pressure is advisory. The WebView stays mounted so an active round
  /// is not destroyed; remote HTML may trim reconstructable presentation data.
  @override
  Future<void> onMemoryPressure() async {
    if (_released) return;
    await _runtime.sendHostEvent('app.memory_pressure');
  }

  /// Authenticated-session teardown is terminal for this registration.
  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _runtime.dispose();
  }
}
