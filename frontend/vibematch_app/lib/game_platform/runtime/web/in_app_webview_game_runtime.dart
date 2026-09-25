import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../application/game_host_bridge.dart';
import '../../domain/game_manifest.dart';
import '../game_runtime.dart';

typedef GameRuntimeErrorHandler = void Function(String message);

/// Invoked after the concrete WebView controller has been created.
typedef GameRuntimeReadyHandler = void Function();

/// Sandboxed single-HTML game runtime.
///
/// The runtime owns only the concrete WebView execution surface. Durable game
/// sessions, rounds, bets and settlement remain backend/Game Platform authority.
class InAppWebViewGameRuntime implements GameRuntime {
  InAppWebViewGameRuntime({
    required VerifiedGameBundle bundle,
    required GameHostBridge bridge,
    required GameRuntimeErrorHandler onError,
    GameRuntimeReadyHandler? onReady,
  }) : _bundle = bundle,
       _bridge = bridge,
       _onError = onError,
       _onReady = onReady;

  static const String _handlerName = 'funkeyGameRequest';

  final VerifiedGameBundle _bundle;
  final GameHostBridge _bridge;
  final GameRuntimeErrorHandler _onError;
  final GameRuntimeReadyHandler? _onReady;
  final GlobalKey _webViewKey = GlobalKey();

  InAppWebViewController? _controller;
  bool _disposed = false;
  bool _initialDocumentLoaded = false;

  @override
  Widget buildView({Key? key}) {
    if (_disposed) return const SizedBox.shrink();

    return InAppWebView(
      key: key ?? _webViewKey,
      initialData: InAppWebViewInitialData(
        data: _securedHtml(_bundle),
        mimeType: 'text/html',
        encoding: 'utf-8',
        baseUrl: WebUri(_bundle.manifest.entryUri.toString()),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: false,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        supportZoom: false,
        transparentBackground: true,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: _handlerName,
          callback: (arguments) async {
            if (arguments.isEmpty) {
              return const <String, dynamic>{
                'ok': false,
                'error': 'Invalid host bridge request.',
              };
            }
            return _bridge.handle(arguments.first);
          },
        );
        _onReady?.call();
      },
      onLoadStart: (controller, url) {
        if (!_initialDocumentLoaded || url == null) return;
        final uri = Uri.tryParse(url.toString());
        if (uri == null || uri.toString() == 'about:blank') return;
        unawaited(controller.stopLoading());
        _onError('Remote game navigation was blocked by the host.');
      },
      onLoadStop: (controller, url) {
        _initialDocumentLoaded = true;
        unawaited(_installBridge());
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame == true) {
          _onError('Remote game failed to load.');
        }
      },
    );
  }

  Future<void> _installBridge() async {
    if (_disposed) return;
    final controller = _controller;
    if (controller == null) return;

    final bridgeVersion = _bundle.manifest.bridgeVersion;
    final source = '''
(() => {
  if (!window.flutter_inappwebview) return;
  const request = async (method, params = {}) => {
    return await window.flutter_inappwebview.callHandler(
      '$_handlerName',
      { method: String(method || ''), params: params || {} }
    );
  };
  Object.defineProperty(window, 'FunKeyHost', {
    value: Object.freeze({
      bridgeVersion: $bridgeVersion,
      request
    }),
    configurable: false,
    writable: false
  });
  window.dispatchEvent(new CustomEvent('funkey:ready', {
    detail: { bridgeVersion: $bridgeVersion }
  }));
})()
''';

    try {
      await controller.evaluateJavascript(source: source);
    } catch (_) {
      _onError('Remote game bridge could not be initialized.');
    }
  }

  @override
  Future<void> sendHostEvent(
    String event, {
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    if (_disposed) return;
    final controller = _controller;
    if (controller == null) return;
    final eventJson = jsonEncode(event);
    final payloadJson = jsonEncode(payload);
    await controller.evaluateJavascript(
      source: '''
window.dispatchEvent(new CustomEvent('funkey:host', {
  detail: { event: $eventJson, payload: $payloadJson }
}));
''',
    );
  }

  @override
  Future<void> reload() async {
    if (_disposed) return;
    _initialDocumentLoaded = false;
    await _controller?.reload();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _controller = null;
  }

  static String _securedHtml(VerifiedGameBundle bundle) {
    final origins = bundle.manifest.allowedOrigins.join(' ');
    final policy = [
      "default-src 'none'",
      "script-src 'unsafe-inline'",
      "style-src 'unsafe-inline' $origins",
      "img-src data: blob: $origins",
      "font-src data: $origins",
      "media-src data: blob: $origins",
      "connect-src 'none'",
      "frame-src 'none'",
      "object-src 'none'",
      "form-action 'none'",
      "base-uri 'none'",
    ].join('; ');
    final meta =
        '<meta http-equiv="Content-Security-Policy" content="$policy">';

    final head = RegExp(r'<head(?:\s[^>]*)?>', caseSensitive: false);
    if (head.hasMatch(bundle.html)) {
      return bundle.html.replaceFirstMapped(
        head,
        (match) => '${match.group(0)}$meta',
      );
    }
    return '$meta${bundle.html}';
  }
}
