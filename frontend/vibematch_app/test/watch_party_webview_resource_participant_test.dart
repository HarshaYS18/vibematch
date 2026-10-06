import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/foundation/runtime/media_resource_lifecycle.dart';
import 'package:vibematch_app/watch_party/domain/watch_party_state.dart';
import 'package:vibematch_app/watch_party/domain/watch_provider_adapter.dart';
import 'package:vibematch_app/watch_party/providers/web/ott_javascript_bridge.dart';
import 'package:vibematch_app/watch_party/providers/web/ott_playback_probe_result.dart';
import 'package:vibematch_app/watch_party/providers/web/ott_web_playback_host.dart';
import 'package:vibematch_app/watch_party/providers/web/watch_party_webview_resource_participant.dart';

/// Chunk 34-M8 behavioral coverage for embedded OTT WebView lifecycle.
void main() {
  test('exposes stable Watch Party WebView resource kind', () {
    final host = _FakeOttHost();
    final participant = WatchPartyWebViewResourceParticipant(
      resourceId: 'watch-party:webview:room-1:netflix',
      host: host,
    );

    expect(participant.resourceId, 'watch-party:webview:room-1:netflix');
    expect(participant.kind, MediaResourceKind.watchPartyWebView);
  });

  test('background pauses embedded playback but foreground does not force play', () async {
    final host = _FakeOttHost();
    final participant = WatchPartyWebViewResourceParticipant(
      resourceId: 'watch-party:webview:room-1:netflix',
      host: host,
    );

    await participant.onForegroundChanged(false);
    await participant.onForegroundChanged(true);

    expect(host.pauseCount, 1);
    expect(host.playCount, 0);
  });

  test('memory pressure is intentionally non-destructive', () async {
    final host = _FakeOttHost();
    final participant = WatchPartyWebViewResourceParticipant(
      resourceId: 'watch-party:webview:room-1:prime_video',
      host: host,
    );

    await participant.onMemoryPressure();

    expect(host.pauseCount, 0);
    expect(host.disposeCount, 0);
  });

  test('session release disposes once and makes later lifecycle inert', () async {
    final host = _FakeOttHost();
    final participant = WatchPartyWebViewResourceParticipant(
      resourceId: 'watch-party:webview:room-1:jiohotstar',
      host: host,
    );

    await participant.release();
    await participant.release();
    await participant.onForegroundChanged(false);
    await participant.onMemoryPressure();

    expect(host.disposeCount, 1);
    expect(host.pauseCount, 0);
  });
}

class _FakeOttHost implements OttWebPlaybackHost {
  int playCount = 0;
  int pauseCount = 0;
  int disposeCount = 0;

  @override
  Stream<OttJavascriptEvent> get events => Stream<OttJavascriptEvent>.empty();

  @override
  Widget buildView({Key? key}) => const SizedBox.shrink();

  @override
  Future<void> load(WatchSession session) async {}

  @override
  Future<OttPlaybackProbeResult> probe() async =>
      const OttPlaybackProbeResult.unavailable(
        failureReason: 'TEST',
      );

  @override
  Future<void> play() async {
    playCount += 1;
  }

  @override
  Future<void> pause() async {
    pauseCount += 1;
  }

  @override
  Future<void> seekTo(int positionMs) async {}

  @override
  Future<void> setPlaybackRate(double playbackRate) async {}

  @override
  Future<int> currentPositionMs() async => 0;

  @override
  Future<WatchLiveTimeline?> currentLiveTimeline() async => null;

  @override
  Future<void> dispose() async {
    disposeCount += 1;
  }
}
