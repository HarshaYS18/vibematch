import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../foundation/telemetry/app_telemetry.dart';
import '../../domain/watch_party_state.dart';
import '../../domain/watch_provider_adapter.dart';
import '../companion/companion_playback_adapter.dart';
import 'ott_javascript_bridge.dart';
import 'ott_playback_probe_result.dart';
import 'ott_provider_definition.dart';
import 'ott_web_playback_host.dart';

enum OttRuntimeMode {
  probing,
  embedded,
  companion,
}

class OttProviderRuntimeState {
  const OttProviderRuntimeState({
    required this.mode,
    required this.probe,
    required this.errorCode,
  });

  const OttProviderRuntimeState.probing()
    : mode = OttRuntimeMode.probing,
      probe = null,
      errorCode = null;

  final OttRuntimeMode mode;
  final OttPlaybackProbeResult? probe;
  final String? errorCode;
}

class SupportedWebPlaybackAdapter
    implements
        WatchProviderAdapter,
        LiveWatchProviderAdapter,
        ExternalWatchProviderAdapter {
  SupportedWebPlaybackAdapter({
    required OttProviderDefinition provider,
    required OttWebPlaybackHost host,
    required CompanionPlaybackAdapter companion,
    AppTelemetry telemetry = const AppTelemetry(),
  }) : _provider = provider,
       _host = host,
       _companion = companion,
       _telemetry = telemetry {
    _eventSubscription = _host.events.listen(_onHostEvent);
  }

  final OttProviderDefinition _provider;
  final OttWebPlaybackHost _host;
  final CompanionPlaybackAdapter _companion;
  final AppTelemetry _telemetry;

  late final StreamSubscription<OttJavascriptEvent> _eventSubscription;
  final ValueNotifier<OttProviderRuntimeState> runtimeState =
      ValueNotifier<OttProviderRuntimeState>(
        const OttProviderRuntimeState.probing(),
      );

  WatchSession? _session;
  bool _disposed = false;

  @override
  String get providerId => _provider.id;

  String get displayName => _provider.displayName;

  Widget buildWebView({Key? key}) => _host.buildView(key: key);

  @override
  WatchProviderCapabilities get capabilities {
    final probe = runtimeState.value.probe;
    final embedded =
        runtimeState.value.mode == OttRuntimeMode.embedded && probe != null;
    if (!embedded) return _companion.capabilities;

    final live = _session?.timelineMode == WatchTimelineMode.live;
    return WatchProviderCapabilities(
      embeddedPlayback: true,
      programmaticPlay: probe.programmaticPlay,
      programmaticPause: probe.programmaticPause,
      programmaticSeek: probe.programmaticSeek,
      programmaticPosition: probe.positionReadable,
      playbackRateControl: probe.playbackRateControl,
      fineGrainedPlaybackRateControl: probe.fineGrainedPlaybackRateControl,
      liveTimelineAvailable: probe.liveTimelineAvailable,
      liveResync: probe.liveTimelineAvailable,
      manualPlayPause:
          !live && probe.programmaticPlay && probe.programmaticPause,
      manualSeek: !live && probe.programmaticSeek,
      externalLaunch: true,
    );
  }

  @override
  Future<void> load(WatchSession session) async {
    if (_disposed) return;
    if (session.provider.trim().toLowerCase() != providerId) {
      throw StateError(
        'OTT provider $providerId cannot render ${session.provider}.',
      );
    }
    _session = session;
    await _companion.load(session);
    runtimeState.value = const OttProviderRuntimeState.probing();
    _record('watch_party_ott_embedded_attempt');

    try {
      await _host.load(session);
      final probe = await _host.probe();
      _applyProbe(probe, fallbackIfUnavailable: false);
    } catch (_) {
      _useCompanion('EMBEDDED_PLAYBACK_UNSUPPORTED');
    }
  }

  Future<bool> retryEmbeddedProbe({
    bool fallbackIfUnavailable = true,
  }) async {
    if (_disposed) return false;
    runtimeState.value = OttProviderRuntimeState(
      mode: OttRuntimeMode.probing,
      probe: runtimeState.value.probe,
      errorCode: null,
    );
    final probe = await _host.probe();
    _applyProbe(probe, fallbackIfUnavailable: fallbackIfUnavailable);
    return runtimeState.value.mode == OttRuntimeMode.embedded;
  }

  void useCompanionFallback() {
    _useCompanion('USER_SELECTED_COMPANION');
  }

  void _applyProbe(
    OttPlaybackProbeResult probe, {
    required bool fallbackIfUnavailable,
  }) {
    _record(
      'watch_party_ott_probe',
      <String, Object?>{
        'page_supported': probe.pageSupported,
        'player_available': probe.playerAvailable,
        'playback_available': probe.playbackAvailable,
        'position_readable': probe.positionReadable,
        'live_timeline_available': probe.liveTimelineAvailable,
        'failure_reason': probe.failureReason,
      },
    );

    if (probe.embeddedPlaybackReady) {
      runtimeState.value = OttProviderRuntimeState(
        mode: OttRuntimeMode.embedded,
        probe: probe,
        errorCode: null,
      );
      _record('watch_party_ott_embedded_ready');
      return;
    }

    if (probe.fallbackRequired ||
        !probe.pageSupported ||
        fallbackIfUnavailable) {
      _useCompanion(
        probe.failureReason ?? 'EMBEDDED_PLAYBACK_UNSUPPORTED',
        probe: probe,
      );
      return;
    }

    runtimeState.value = OttProviderRuntimeState(
      mode: OttRuntimeMode.probing,
      probe: probe,
      errorCode:
          probe.failureReason ?? 'LOGIN_REQUIRED_OR_PLAYER_UNAVAILABLE',
    );
  }

  @override
  Future<void> play() => _embeddedCommand(_host.play);

  @override
  Future<void> pause() => _embeddedCommand(_host.pause);

  @override
  Future<void> seekTo(int positionMs) {
    return _embeddedCommand(() => _host.seekTo(positionMs));
  }

  @override
  Future<void> setPlaybackRate(double playbackRate) {
    return _embeddedCommand(() => _host.setPlaybackRate(playbackRate));
  }

  @override
  Future<int> currentPositionMs() async {
    if (runtimeState.value.mode != OttRuntimeMode.embedded) {
      return _session?.positionMs ?? 0;
    }
    try {
      return await _host.currentPositionMs();
    } catch (_) {
      _useCompanion('PLAYBACK_POSITION_UNAVAILABLE');
      return _session?.positionMs ?? 0;
    }
  }

  @override
  Future<WatchLiveTimeline?> currentLiveTimeline() async {
    if (runtimeState.value.mode != OttRuntimeMode.embedded) return null;
    try {
      return await _host.currentLiveTimeline();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> launchExternal() async {
    final launched = await _companion.launchExternal();
    _record(
      'watch_party_ott_external_launch',
      <String, Object?>{'success': launched},
    );
    return launched;
  }

  @override
  Future<void> restoreAfterExternalLaunch() async {
    await _companion.restoreAfterExternalLaunch();
    if (_disposed) return;
    await retryEmbeddedProbe(fallbackIfUnavailable: false);
  }

  Future<void> _embeddedCommand(Future<void> Function() operation) async {
    if (runtimeState.value.mode != OttRuntimeMode.embedded) return;
    try {
      await operation();
    } catch (_) {
      _useCompanion('PLAYBACK_FAILED');
    }
  }

  void _onHostEvent(OttJavascriptEvent event) {
    if (_disposed || event.provider != providerId) return;
    if (event.type == OttJavascriptEventType.playbackError) {
      _useCompanion('PLAYBACK_FAILED');
    } else if (event.type == OttJavascriptEventType.drmError) {
      _useCompanion('DRM_UNAVAILABLE');
    }
  }

  void _useCompanion(
    String errorCode, {
    OttPlaybackProbeResult? probe,
  }) {
    if (_disposed) return;
    runtimeState.value = OttProviderRuntimeState(
      mode: OttRuntimeMode.companion,
      probe: probe ?? runtimeState.value.probe,
      errorCode: errorCode,
    );
    _record(
      'watch_party_ott_companion_fallback',
      <String, Object?>{'reason': errorCode},
    );
  }

  void _record(
    String event, [
    Map<String, Object?> attributes = const <String, Object?>{},
  ]) {
    _telemetry.record(
      event,
      attributes: <String, Object?>{
        'provider': providerId,
        ...attributes,
      },
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _eventSubscription.cancel();
    await _host.dispose();
    await _companion.dispose();
    runtimeState.dispose();
  }
}
