import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/watch_party/domain/watch_party_state.dart';
import 'package:vibematch_app/watch_party/domain/watch_provider_adapter.dart';
import 'package:vibematch_app/watch_party/providers/companion/companion_playback_adapter.dart';
import 'package:vibematch_app/watch_party/providers/web/ott_javascript_bridge.dart';
import 'package:vibematch_app/watch_party/providers/web/ott_playback_probe_result.dart';
import 'package:vibematch_app/watch_party/providers/web/ott_provider_definition.dart';
import 'package:vibematch_app/watch_party/providers/web/ott_web_playback_host.dart';
import 'package:vibematch_app/watch_party/providers/web/supported_web_playback_adapter.dart';

class _FakeOttHost implements OttWebPlaybackHost {
  _FakeOttHost({required this.probeResult});

  OttPlaybackProbeResult probeResult;
  int positionMs = 0;
  WatchLiveTimeline? liveTimeline;
  WatchSession? loaded;
  int loadCount = 0;
  bool disposed = false;
  final StreamController<OttJavascriptEvent> controller =
      StreamController<OttJavascriptEvent>.broadcast();

  @override
  Stream<OttJavascriptEvent> get events => controller.stream;

  @override
  Widget buildView({Key? key}) => SizedBox(key: key);

  @override
  Future<void> load(WatchSession session) async {
    loadCount += 1;
    loaded = session;
    positionMs = session.positionMs;
  }

  @override
  Future<OttPlaybackProbeResult> probe() async => probeResult;

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seekTo(int positionMs) async {
    this.positionMs = positionMs;
  }

  @override
  Future<void> setPlaybackRate(double playbackRate) async {}

  @override
  Future<int> currentPositionMs() async => positionMs;

  @override
  Future<WatchLiveTimeline?> currentLiveTimeline() async => liveTimeline;

  @override
  Future<void> dispose() async {
    disposed = true;
    await controller.close();
  }
}

WatchSession _session({
  String provider = 'netflix',
  WatchTimelineMode timelineMode = WatchTimelineMode.vod,
}) {
  return WatchSession(
    active: true,
    sessionId: 'ott-session',
    roomId: 'VM123',
    provider: provider,
    contentId: null,
    contentUrl: 'https://www.netflix.com/watch/81234567',
    contentTitle: 'Test',
    hostUserId: 1,
    controllerUserId: 1,
    playbackState: WatchPlaybackState.paused,
    positionMs: 12000,
    serverAnchorTimeMs: 100000,
    playbackRate: 1,
    revision: 1,
    eventSequence: 1,
    timelineMode: timelineMode,
  );
}

const _readyProbe = OttPlaybackProbeResult(
  pageSupported: true,
  authenticated: true,
  playerAvailable: true,
  playbackAvailable: true,
  positionReadable: true,
  programmaticPlay: true,
  programmaticPause: true,
  programmaticSeek: true,
  playbackRateControl: true,
  fineGrainedPlaybackRateControl: false,
  liveTimelineAvailable: true,
  failureReason: null,
  fallbackRequired: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('verified HTML5 capability enables embedded mode', () async {
    final host = _FakeOttHost(probeResult: _readyProbe);
    final companion = CompanionPlaybackAdapter(
      provider: OttProviderCatalog.netflix,
      launcher: (_) async => true,
    );
    final adapter = SupportedWebPlaybackAdapter(
      provider: OttProviderCatalog.netflix,
      host: host,
      companion: companion,
    );

    await adapter.load(_session());

    expect(adapter.runtimeState.value.mode, OttRuntimeMode.embedded);
    expect(adapter.capabilities.embeddedPlayback, isTrue);
    expect(adapter.capabilities.fineGrainedPlaybackRateControl, isFalse);
    await adapter.dispose();
    expect(host.disposed, isTrue);
  });

  test('unsupported embedded runtime falls back to companion mode', () async {
    final host = _FakeOttHost(
      probeResult: const OttPlaybackProbeResult.unavailable(
        failureReason: 'EMBEDDED_PLAYBACK_UNSUPPORTED',
      ),
    );
    final companion = CompanionPlaybackAdapter(
      provider: OttProviderCatalog.netflix,
      launcher: (_) async => true,
    );
    final adapter = SupportedWebPlaybackAdapter(
      provider: OttProviderCatalog.netflix,
      host: host,
      companion: companion,
    );

    await adapter.load(_session());

    expect(adapter.runtimeState.value.mode, OttRuntimeMode.companion);
    expect(adapter.capabilities.embeddedPlayback, isFalse);
    expect(adapter.capabilities.externalLaunch, isTrue);
    await adapter.dispose();
  });

  test('login/player not ready stays in probing before forced fallback', () async {
    final host = _FakeOttHost(
      probeResult: const OttPlaybackProbeResult(
        pageSupported: true,
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
        fallbackRequired: false,
      ),
    );
    final companion = CompanionPlaybackAdapter(
      provider: OttProviderCatalog.netflix,
      launcher: (_) async => true,
    );
    final adapter = SupportedWebPlaybackAdapter(
      provider: OttProviderCatalog.netflix,
      host: host,
      companion: companion,
    );

    await adapter.load(_session());
    expect(adapter.runtimeState.value.mode, OttRuntimeMode.probing);

    final retried = await adapter.retryEmbeddedProbe();
    expect(retried, isFalse);
    expect(adapter.runtimeState.value.mode, OttRuntimeMode.companion);
    await adapter.dispose();
  });

  test('retry waits for remount and reloads canonical session', () async {
    final host = _FakeOttHost(
      probeResult: const OttPlaybackProbeResult(
        pageSupported: true,
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
        fallbackRequired: false,
      ),
    );
    final companion = CompanionPlaybackAdapter(
      provider: OttProviderCatalog.netflix,
      launcher: (_) async => true,
    );
    var remountBarrierCalls = 0;
    final adapter = SupportedWebPlaybackAdapter(
      provider: OttProviderCatalog.netflix,
      host: host,
      companion: companion,
      remountBarrier: () async {
        remountBarrierCalls += 1;
      },
    );

    await adapter.load(_session());
    expect(adapter.runtimeState.value.mode, OttRuntimeMode.probing);
    expect(host.loadCount, 1);

    host.probeResult = _readyProbe;
    final ready = await adapter.retryEmbeddedProbe(
      fallbackIfUnavailable: false,
    );

    expect(ready, isTrue);
    expect(remountBarrierCalls, 1);
    expect(host.loadCount, 2);
    expect(host.loaded?.sessionId, 'ott-session');
    await adapter.dispose();
  });

  test('companion launches the participant provider URL only', () async {
    Uri? launchedUri;
    final host = _FakeOttHost(
      probeResult: const OttPlaybackProbeResult.unavailable(
        failureReason: 'NO_WEB_PLAYBACK',
      ),
    );
    final companion = CompanionPlaybackAdapter(
      provider: OttProviderCatalog.netflix,
      launcher: (uri) async {
        launchedUri = uri;
        return true;
      },
    );
    final adapter = SupportedWebPlaybackAdapter(
      provider: OttProviderCatalog.netflix,
      host: host,
      companion: companion,
    );

    await adapter.load(_session());
    expect(await adapter.launchExternal(), isTrue);
    expect(launchedUri?.host, 'www.netflix.com');
    expect(launchedUri?.path, '/watch/81234567');
    await adapter.dispose();
  });
}
