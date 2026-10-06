import '../../domain/watch_party_state.dart';
import '../../domain/watch_provider_adapter.dart';
import 'youtube_content_id.dart';
import 'youtube_player_port.dart';

class YoutubeWatchAdapter implements WatchProviderAdapter {
  YoutubeWatchAdapter({required YoutubePlayerPort player}) : _player = player;

  final YoutubePlayerPort _player;
  bool _disposed = false;

  @override
  String get providerId => 'youtube';

  @override
  WatchProviderCapabilities get capabilities =>
      const WatchProviderCapabilities(
        embeddedPlayback: true,
        programmaticPlay: true,
        programmaticPause: true,
        programmaticSeek: true,
        programmaticPosition: true,
        playbackRateControl: true,
        fineGrainedPlaybackRateControl: false,
        externalLaunch: true,
      );

  @override
  Future<void> load(WatchSession session) async {
    _ensureActive();
    final videoId =
        YouTubeContentId.tryParse(session.contentId) ??
        YouTubeContentId.tryParse(session.contentUrl);
    if (videoId == null) {
      throw StateError('Watch Party contains an invalid YouTube video.');
    }
    await _player.cueVideo(
      videoId: videoId,
      startSeconds: session.positionMs.clamp(0, 1 << 62).toDouble() / 1000,
    );
  }

  @override
  Future<void> play() {
    _ensureActive();
    return _player.play();
  }

  @override
  Future<void> pause() {
    _ensureActive();
    return _player.pause();
  }

  @override
  Future<void> seekTo(int positionMs) {
    _ensureActive();
    return _player.seekToMs(positionMs);
  }

  @override
  Future<int> currentPositionMs() {
    _ensureActive();
    return _player.currentPositionMs();
  }

  @override
  Future<void> setPlaybackRate(double playbackRate) async {
    _ensureActive();
    final rates = await _player.availablePlaybackRates();
    if (rates.isEmpty) return;

    var selected = rates.first;
    var selectedDistance = (selected - playbackRate).abs();
    for (final candidate in rates.skip(1)) {
      final distance = (candidate - playbackRate).abs();
      if (distance < selectedDistance) {
        selected = candidate;
        selectedDistance = distance;
      }
    }
    await _player.setPlaybackRate(selected);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _player.close();
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('YouTube Watch Party adapter is disposed.');
    }
  }
}
