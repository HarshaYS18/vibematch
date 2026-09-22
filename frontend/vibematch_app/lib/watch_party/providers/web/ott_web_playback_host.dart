import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../domain/watch_party_state.dart';
import '../../domain/watch_provider_adapter.dart';
import 'desktop_chrome_browser_profile.dart';
import 'html5_video_playback_driver.dart';
import 'ott_javascript_bridge.dart';
import 'ott_playback_probe_result.dart';
import 'ott_provider_definition.dart';

abstract interface class OttWebPlaybackHost {
  Stream<OttJavascriptEvent> get events;

  Widget buildView({Key? key});
  Future<void> load(WatchSession session);
  Future<OttPlaybackProbeResult> probe();
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(int positionMs);
  Future<void> setPlaybackRate(double playbackRate);
  Future<int> currentPositionMs();
  Future<WatchLiveTimeline?> currentLiveTimeline();
  Future<void> dispose();
}

class InAppWebViewOttPlaybackHost implements OttWebPlaybackHost {
  InAppWebViewOttPlaybackHost({
    required OttProviderDefinition provider,
  }) : _provider = provider {
    _driver = Html5VideoPlaybackDriver(
      evaluate: _evaluate,
      providerId: provider.id,
    );
  }

  final OttProviderDefinition _provider;
  final StreamController<OttJavascriptEvent> _events =
      StreamController<OttJavascriptEvent>.broadcast();
  final GlobalKey _webViewKey = GlobalKey();

  late final Html5VideoPlaybackDriver _driver;
  InAppWebViewController? _controller;
  Uri? _pendingUri;
  Uri? _loadedUri;
  Completer<void> _pageReady = Completer<void>();
  String? _lastLoadError;
  bool _disposed = false;

  @override
  Stream<OttJavascriptEvent> get events => _events.stream;

  @override
  Widget buildView({Key? key}) {
    if (_disposed) return const SizedBox.shrink();
    final initialUri = _pendingUri ?? _provider.homeUri;
    return InAppWebView(
      key: key ?? _webViewKey,
      initialUrlRequest: URLRequest(url: WebUri(initialUri.toString())),
      initialSettings: DesktopChromeBrowserProfile.settings(),
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: OttJavascriptBridge.handlerName,
          callback: (arguments) {
            final event = OttJavascriptBridge.tryParse(arguments);
            if (event != null &&
                event.provider == _provider.id &&
                !_events.isClosed) {
              _events.add(event);
            }
            return null;
          },
        );
      },
      onLoadStart: (controller, url) {
        _lastLoadError = null;
        _resetReady();
      },
      onLoadStop: (controller, url) {
        if (url != null) {
          _loadedUri = Uri.tryParse(url.toString());
        }
        if (!_pageReady.isCompleted) _pageReady.complete();
        unawaited(_installBridge());
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame == true) {
          _lastLoadError = error.description;
          if (!_pageReady.isCompleted) _pageReady.complete();
        }
      },
    );
  }

  @override
  Future<void> load(WatchSession session) async {
    if (_disposed) throw StateError('OTT WebView host has been disposed.');
    if (session.provider.trim().toLowerCase() != _provider.id) {
      throw StateError(
        'OTT host ${_provider.id} cannot load ${session.provider}.',
      );
    }
    final uri = _provider.resolveSessionUri(session);
    _pendingUri = uri;

    final controller = _controller;
    if (controller == null) return;
    if (_loadedUri?.toString() == uri.toString() &&
        _lastLoadError == null &&
        _pageReady.isCompleted) {
      return;
    }
    _resetReady();
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(uri.toString())),
    );
  }

  @override
  Future<OttPlaybackProbeResult> probe() async {
    if (_disposed) {
      return const OttPlaybackProbeResult.unavailable(
        failureReason: 'WEBVIEW_DISPOSED',
      );
    }
    try {
      await _pageReady.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      return const OttPlaybackProbeResult.unavailable(
        failureReason: 'PAGE_LOAD_TIMEOUT',
      );
    }

    final loadError = _lastLoadError;
    if (loadError != null && loadError.trim().isNotEmpty) {
      return const OttPlaybackProbeResult.unavailable(
        failureReason: 'PAGE_LOAD_FAILED',
      );
    }
    return _driver.probe();
  }

  @override
  Future<void> play() => _driver.play();

  @override
  Future<void> pause() => _driver.pause();

  @override
  Future<void> seekTo(int positionMs) => _driver.seekTo(positionMs);

  @override
  Future<void> setPlaybackRate(double playbackRate) =>
      _driver.setPlaybackRate(playbackRate);

  @override
  Future<int> currentPositionMs() => _driver.currentPositionMs();

  @override
  Future<WatchLiveTimeline?> currentLiveTimeline() =>
      _driver.currentLiveTimeline();

  Future<dynamic> _evaluate(String source) async {
    final controller = _controller;
    if (controller == null) {
      throw StateError('OTT WebView is not ready.');
    }
    return controller.evaluateJavascript(source: source);
  }

  Future<void> _installBridge() async {
    final providerId = _provider.id;
    final source = '''
(() => {
  const provider = '$providerId';
  const send = (type, extra = {}) => {
    try {
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler(
          '${OttJavascriptBridge.handlerName}',
          Object.assign({type, provider}, extra)
        );
      }
    } catch (_) {}
  };

  const bind = () => {
    const video = document.querySelector('video');
    if (!video) {
      send('LOGIN_REQUIRED');
      return false;
    }
    if (video.dataset.funkeyWatchBridge === '1') return true;
    video.dataset.funkeyWatchBridge = '1';

    const state = () => ({
      state: video.paused ? 'paused' : 'playing',
      positionMs: Number.isFinite(video.currentTime)
          ? Math.round(video.currentTime * 1000)
          : null,
      durationMs: Number.isFinite(video.duration)
          ? Math.round(video.duration * 1000)
          : null,
      playbackRate: Number(video.playbackRate || 1),
      live: !Number.isFinite(video.duration) || video.duration === Infinity
    });

    const markPlaybackObserved = () => {
      const source = video.currentSrc || video.src || '';
      if (!source) return;
      video.dataset.funkeyPlaybackObserved = '1';
      video.dataset.funkeyPlaybackSource = source;
    };

    if (!video.paused && video.readyState >= 3) {
      markPlaybackObserved();
    }

    video.addEventListener('loadedmetadata', () => send('PLAYER_READY', state()));
    video.addEventListener('play', () => send('PLAYER_STATE', state()));
    video.addEventListener('playing', () => {
      markPlaybackObserved();
      send('PLAYER_STATE', state());
    });
    video.addEventListener('pause', () => send('PLAYER_STATE', state()));
    video.addEventListener('waiting', () => send('BUFFERING', state()));
    video.addEventListener('error', () => send('PLAYBACK_ERROR', {
      ...state(),
      error: video.error ? String(video.error.message || video.error.code) : 'unknown'
    }));
    video.addEventListener('timeupdate', () => send('POSITION', state()));
    send('PLAYER_READY', state());
    return true;
  };

  bind();
  const root = document.documentElement;
  if (root && !window.__funkeyWatchObserver) {
    window.__funkeyWatchObserver = new MutationObserver(() => bind());
    window.__funkeyWatchObserver.observe(root, {childList: true, subtree: true});
  }
})()
''';
    try {
      await _evaluate(source);
    } catch (_) {
      // Capability probing will convert bridge/JS restrictions into fallback.
    }
  }

  void _resetReady() {
    if (_pageReady.isCompleted) {
      _pageReady = Completer<void>();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _controller = null;
    await _events.close();
  }
}
