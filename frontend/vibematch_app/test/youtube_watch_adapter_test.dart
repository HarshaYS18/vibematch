import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/watch_party/domain/watch_party_state.dart';
import 'package:vibematch_app/watch_party/providers/youtube/youtube_player_port.dart';
import 'package:vibematch_app/watch_party/providers/youtube/youtube_watch_adapter.dart';

class _FakeYoutubePlayerPort implements YoutubePlayerPort {
  String? cuedVideoId;
  double? cueStartSeconds;
  bool playing = false;
  int positionMs = 0;
  double appliedRate = 1;
  bool closed = false;
  List<double> rates = const <double>[0.5, 1, 1.5, 2];

  @override
  Future<void> cueVideo({
    required String videoId,
    required double startSeconds,
  }) async {
    cuedVideoId = videoId;
    cueStartSeconds = startSeconds;
    positionMs = (startSeconds * 1000).round();
  }

  @override
  Future<void> play() async => playing = true;

  @override
  Future<void> pause() async => playing = false;

  @override
  Future<void> seekToMs(int positionMs) async => this.positionMs = positionMs;

  @override
  Future<int> currentPositionMs() async => positionMs;

  @override
  Future<List<double>> availablePlaybackRates() async => rates;

  @override
  Future<void> setPlaybackRate(double playbackRate) async {
    appliedRate = playbackRate;
  }

  @override
  Future<void> close() async => closed = true;
}

WatchSession _session({
  String? contentId = 'dQw4w9WgXcQ',
  String? contentUrl,
  int positionMs = 12345,
}) {
  return WatchSession(
    active: true,
    sessionId: 'session-youtube',
    roomId: 'VM123',
    provider: 'youtube',
    contentId: contentId,
    contentUrl: contentUrl,
    contentTitle: 'Video',
    hostUserId: 1,
    controllerUserId: 1,
    playbackState: WatchPlaybackState.paused,
    positionMs: positionMs,
    serverAnchorTimeMs: 100000,
    playbackRate: 1,
    revision: 1,
    eventSequence: 1,
  );
}

void main() {
  test('YouTube adapter exposes integrated playback capabilities', () {
    final adapter = YoutubeWatchAdapter(player: _FakeYoutubePlayerPort());
    final capabilities = adapter.capabilities;

    expect(capabilities.embeddedPlayback, isTrue);
    expect(capabilities.programmaticPlay, isTrue);
    expect(capabilities.programmaticPause, isTrue);
    expect(capabilities.programmaticSeek, isTrue);
    expect(capabilities.programmaticPosition, isTrue);
    expect(capabilities.playbackRateControl, isTrue);
    expect(capabilities.fineGrainedPlaybackRateControl, isFalse);
  });

  test('loads canonical content and converts milliseconds correctly', () async {
    final port = _FakeYoutubePlayerPort();
    final adapter = YoutubeWatchAdapter(player: port);

    await adapter.load(_session());

    expect(port.cuedVideoId, 'dQw4w9WgXcQ');
    expect(port.cueStartSeconds, closeTo(12.345, 0.0001));
  });

  test('maps seek and current position through the player port', () async {
    final port = _FakeYoutubePlayerPort();
    final adapter = YoutubeWatchAdapter(player: port);

    await adapter.seekTo(65432);
    expect(await adapter.currentPositionMs(), 65432);
  });

  test('rounds requested playback rate to a supported YouTube rate', () async {
    final port = _FakeYoutubePlayerPort();
    final adapter = YoutubeWatchAdapter(player: port);

    await adapter.setPlaybackRate(1.08);

    expect(port.appliedRate, 1);
  });

  test('rejects invalid YouTube content', () async {
    final adapter = YoutubeWatchAdapter(player: _FakeYoutubePlayerPort());

    expect(
      () => adapter.load(
        _session(contentId: null, contentUrl: 'https://example.com/video'),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('dispose is idempotent', () async {
    final port = _FakeYoutubePlayerPort();
    final adapter = YoutubeWatchAdapter(player: port);

    await adapter.dispose();
    await adapter.dispose();

    expect(port.closed, isTrue);
  });
}
