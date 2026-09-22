import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/watch_party/application/watch_party_clock.dart';
import 'package:vibematch_app/watch_party/application/watch_party_coordinator.dart';
import 'package:vibematch_app/watch_party/domain/watch_party_state.dart';
import 'package:vibematch_app/watch_party/domain/watch_provider_adapter.dart';

class _FakeWatchAdapter implements WatchProviderAdapter {
  _FakeWatchAdapter({
    required this.providerId,
    this.positionMs = 0,
  });

  @override
  final String providerId;

  int positionMs;
  double playbackRate = 1;
  bool playing = false;
  bool disposed = false;
  int seekCount = 0;
  String? loadedSessionId;

  @override
  WatchProviderCapabilities get capabilities =>
      const WatchProviderCapabilities(
        embeddedPlayback: true,
        programmaticPlay: true,
        programmaticPause: true,
        programmaticSeek: true,
        programmaticPosition: true,
        playbackRateControl: true,
        externalLaunch: false,
      );

  @override
  Future<void> load(WatchSession session) async {
    loadedSessionId = session.sessionId;
    positionMs = session.positionMs;
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
  Future<void> seekTo(int positionMs) async {
    this.positionMs = positionMs;
    seekCount += 1;
  }

  @override
  Future<void> setPlaybackRate(double playbackRate) async {
    this.playbackRate = playbackRate;
  }

  @override
  Future<int> currentPositionMs() async => positionMs;

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

WatchSession _session({
  String id = 'session-1',
  int positionMs = 10000,
  int anchorMs = 100000,
  WatchPlaybackState playbackState = WatchPlaybackState.playing,
  int revision = 1,
}) {
  return WatchSession(
    active: true,
    sessionId: id,
    roomId: 'VM123',
    provider: 'fake',
    contentId: 'content-1',
    contentUrl: null,
    contentTitle: 'Test Content',
    hostUserId: 1,
    controllerUserId: 1,
    playbackState: playbackState,
    positionMs: positionMs,
    serverAnchorTimeMs: anchorMs,
    playbackRate: 1,
    revision: revision,
    eventSequence: revision,
  );
}

WatchPartyState _state(WatchSession session, {int serverTimeMs = 105000}) {
  return WatchPartyState(
    roomId: 'VM123',
    session: session,
    serverTimeMs: serverTimeMs,
    errorMessage: null,
  );
}

void main() {
  test('server anchored position ignores local device clock authority', () {
    final session = _session();
    expect(session.targetPositionMsAt(105000), 15000);
  });

  test('two fake providers converge on one authoritative timeline', () async {
    var clientNowA = 5000;
    var clientNowB = 900000;
    final adapterA = _FakeWatchAdapter(providerId: 'fake');
    final adapterB = _FakeWatchAdapter(providerId: 'fake');
    final coordinatorA = WatchPartyCoordinator(
      adapter: adapterA,
      clock: WatchPartyClock(clientNowMs: () => clientNowA),
    );
    final coordinatorB = WatchPartyCoordinator(
      adapter: adapterB,
      clock: WatchPartyClock(clientNowMs: () => clientNowB),
    );

    final state = _state(_session());
    await coordinatorA.reconcile(state);
    await coordinatorB.reconcile(state);

    expect(coordinatorA.clock.serverNowMs, 105000);
    expect(coordinatorB.clock.serverNowMs, 105000);
    expect(adapterA.positionMs, 15000);
    expect(adapterB.positionMs, 15000);
    expect(adapterA.positionMs, adapterB.positionMs);
    expect(adapterA.playing, isTrue);
    expect(adapterB.playing, isTrue);

    clientNowA += 1000;
    clientNowB += 1000;
    await coordinatorA.dispose();
    await coordinatorB.dispose();
    expect(adapterA.disposed, isTrue);
    expect(adapterB.disposed, isTrue);
  });

  test('medium playing drift uses rate correction instead of a seek', () async {
    var clientNow = 5000;
    final adapter = _FakeWatchAdapter(providerId: 'fake');
    final coordinator = WatchPartyCoordinator(
      adapter: adapter,
      clock: WatchPartyClock(clientNowMs: () => clientNow),
    );
    final state = _state(_session());

    await coordinator.reconcile(state);
    final seekCountAfterLoad = adapter.seekCount;

    adapter.positionMs = 14300;
    await coordinator.reconcile(state);

    expect(adapter.seekCount, seekCountAfterLoad);
    expect(adapter.playbackRate, greaterThan(1));
    await coordinator.dispose();
  });
}
