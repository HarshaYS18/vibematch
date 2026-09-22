import '../../domain/watch_provider_adapter.dart';
import 'ott_playback_probe_result.dart';

typedef OttJavascriptEvaluator = Future<dynamic> Function(String source);

class Html5VideoPlaybackDriver {
  Html5VideoPlaybackDriver({
    required OttJavascriptEvaluator evaluate,
    required String providerId,
  }) : _evaluate = evaluate,
       _providerId = providerId;

  final OttJavascriptEvaluator _evaluate;
  final String _providerId;

  Future<OttPlaybackProbeResult> probe() async {
    try {
      final raw = await _evaluate(r'''
(() => {
  const video = document.querySelector('video');
  const pageSupported = !!document.documentElement;
  if (!video) {
    return {
      pageSupported,
      authenticated: false,
      playerAvailable: false,
      playbackAvailable: false,
      positionReadable: false,
      programmaticPlay: false,
      programmaticPause: false,
      programmaticSeek: false,
      playbackRateControl: false,
      fineGrainedPlaybackRateControl: false,
      liveTimelineAvailable: false,
      failureReason: 'LOGIN_REQUIRED_OR_PLAYER_UNAVAILABLE',
      fallbackRequired: false
    };
  }

  const seekable = video.seekable;
  const hasSeekable = !!seekable && seekable.length > 0;
  const sourceAvailable = !!(video.currentSrc || video.src);
  const playbackAvailable = !video.error && sourceAvailable && video.readyState >= 1;
  const positionReadable = Number.isFinite(video.currentTime);
  const programmaticSeek =
      positionReadable && (Number.isFinite(video.duration) || hasSeekable);
  const liveTimelineAvailable = hasSeekable &&
      (!Number.isFinite(video.duration) || video.duration === Infinity);

  return {
    pageSupported,
    authenticated: playbackAvailable,
    playerAvailable: true,
    playbackAvailable,
    positionReadable,
    programmaticPlay: typeof video.play === 'function',
    programmaticPause: typeof video.pause === 'function',
    programmaticSeek,
    playbackRateControl: 'playbackRate' in video,
    fineGrainedPlaybackRateControl: false,
    liveTimelineAvailable,
    failureReason: playbackAvailable ? null : 'PROTECTED_CONTENT_NOT_READY',
    fallbackRequired: false
  };
})()
''');
      final map = _stringKeyMap(raw);
      if (map == null) {
        return const OttPlaybackProbeResult.unavailable(
          failureReason: 'EMBEDDED_PROBE_UNSUPPORTED',
        );
      }
      return OttPlaybackProbeResult.fromMap(map);
    } catch (_) {
      return const OttPlaybackProbeResult.unavailable(
        failureReason: 'EMBEDDED_PROBE_FAILED',
      );
    }
  }

  Future<void> play() {
    return _command(r'''
(() => {
  const video = document.querySelector('video');
  if (!video) return false;
  const pending = video.play();
  if (pending && typeof pending.catch === 'function') {
    pending.catch((error) => {
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('funkeyOttBridge', {
          type: 'PLAYBACK_ERROR',
          provider: '__PROVIDER__',
          error: String(error && error.message ? error.message : error)
        });
      }
    });
  }
  return true;
})()
''');
  }

  Future<void> pause() {
    return _command(r'''
(() => {
  const video = document.querySelector('video');
  if (!video) return false;
  video.pause();
  return true;
})()
''');
  }

  Future<void> seekTo(int positionMs) {
    final seconds = positionMs / 1000;
    return _command('''
(() => {
  const video = document.querySelector('video');
  if (!video || !Number.isFinite(video.currentTime)) return false;
  video.currentTime = $seconds;
  return true;
})()
''');
  }

  Future<int> currentPositionMs() async {
    final raw = await _evaluate(r'''
(() => {
  const video = document.querySelector('video');
  if (!video || !Number.isFinite(video.currentTime)) return null;
  return Math.round(video.currentTime * 1000);
})()
''');
    if (raw is num) return raw.round();
    final parsed = int.tryParse(raw?.toString() ?? '');
    if (parsed == null) {
      throw StateError('OTT player position is unavailable.');
    }
    return parsed;
  }

  Future<void> setPlaybackRate(double playbackRate) {
    final safeRate = playbackRate.clamp(0.25, 4.0).toDouble();
    return _command('''
(() => {
  const video = document.querySelector('video');
  if (!video || !('playbackRate' in video)) return false;
  video.playbackRate = $safeRate;
  return true;
})()
''');
  }

  Future<WatchLiveTimeline?> currentLiveTimeline() async {
    final raw = await _evaluate(r'''
(() => {
  const video = document.querySelector('video');
  if (!video || !video.seekable || video.seekable.length === 0) return null;
  const index = video.seekable.length - 1;
  return {
    seekableStartMs: Math.round(video.seekable.start(index) * 1000),
    liveEdgeMs: Math.round(video.seekable.end(index) * 1000)
  };
})()
''');
    final map = _stringKeyMap(raw);
    if (map == null) return null;
    final start = _integer(map['seekableStartMs']);
    final edge = _integer(map['liveEdgeMs']);
    if (start == null || edge == null || edge < start) return null;
    return WatchLiveTimeline(seekableStartMs: start, liveEdgeMs: edge);
  }

  Future<void> _command(String source) async {
    final result = await _evaluate(
      source.replaceAll('__PROVIDER__', _providerId),
    );
    if (result != true && result?.toString() != 'true') {
      throw StateError('OTT HTML5 player command was not accepted.');
    }
  }

  Map<String, dynamic>? _stringKeyMap(dynamic raw) {
    if (raw is! Map) return null;
    return raw.map<String, dynamic>(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  int? _integer(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    return int.tryParse(raw?.toString() ?? '');
  }
}
