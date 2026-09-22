import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/watch_party/application/watch_party_clock.dart';
import 'package:vibematch_app/watch_party/application/watch_party_coordinator.dart';
import 'package:vibematch_app/watch_party/domain/watch_party_state.dart';
import 'package:vibematch_app/watch_party/domain/watch_provider_adapter.dart';

class _FakeLiveAdapter
    implements WatchProviderAdapter, LiveWatchProviderAdapter {
  int positionMs = 0;
  int seekCount = 0;
  bool playing = false;
  bool disposed = false;

  @override
  String get providerId => 'live_fake';

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
        liveTimelineAvailable: true,
        liveResync: true,
        manualPlayPause: false,
        manualSeek: false,
        externalLaunch: false,
      );

  @override
  Future<void> load(WatchSession session) async {
    positionMs = session.positionMs;
  }

  @override
  Future<WatchLiveTimeline?> currentLiveTimeline() async {
    return const WatchLiveTimeline(
      seekableStartMs: 100000,
      liveEdgeMs: 200000,
    );
  }

  @override
  Future<int> currentPositionMs() async => positionMs;

  @override
  Future<void> seekTo(int positionMs) async {
    this.positionMs = positionMs;
    seekCount += 1;
  }

  @override
  Future<void> play() async {
    playing = true;
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  Future<void> setPlaybackRate(double playbackRate) async {}

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  test('live provider converges to configured latency behind seekable edge',
      () async {
    final adapter = _FakeLiveAdapter();
    final coordinator = WatchPartyCoordinator(
      adapter: adapter,
      clock: WatchPartyClock(clientNowMs: () => 5000),
    );
    final session = WatchSession(
      active: true,
      sessionId: 'live-session',
      roomId: 'VM123',
      provider: 'live_fake',
      contentId: null,
      contentUrl: 'https://example.test/live',
      contentTitle: 'Live',
      hostUserId: 1,
      controllerUserId: 1,
      playbackState: WatchPlaybackState.playing,
      positionMs: 0,
      serverAnchorTimeMs: 100000,
      playbackRate: 1,
      revision: 1,
      eventSequence: 1,
      timelineMode: WatchTimelineMode.live,
      targetLiveLatencyMs: 10000,
    );
    final state = WatchPartyState(
      roomId: 'VM123',
      session: session,
      serverTimeMs: 105000,
      errorMessage: null,
    );

    await coordinator.reconcile(state);

    expect(adapter.positionMs, 190000);
    expect(adapter.seekCount, 1);
    expect(adapter.playing, isTrue);
    await coordinator.dispose();
    expect(adapter.disposed, isTrue);
  });

  test('live target clamps to seekable window', () {
    const timeline = WatchLiveTimeline(
      seekableStartMs: 195000,
      liveEdgeMs: 200000,
    );
    expect(timeline.targetPositionMs(10000), 195000);
    expect(timeline.targetPositionMs(1000), 199000);
  });
}
