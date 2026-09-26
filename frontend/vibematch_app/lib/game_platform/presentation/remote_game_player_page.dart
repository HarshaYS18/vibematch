import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../foundation/di/app_dependencies.dart';
import '../../foundation/runtime/media_resource_lifecycle.dart';
import '../../session/data/session_repository.dart';
import '../application/game_host_bridge.dart';
import '../data/game_manifest_repository.dart';
import '../domain/game_manifest.dart';
import '../runtime/game_runtime.dart';
import '../runtime/game_webview_resource_participant.dart';
import '../runtime/web/in_app_webview_game_runtime.dart';

/// Hosts one verified remote game runtime without becoming game-domain authority.
///
/// Chunk 34 lifecycle registration flows through the foundation resource
/// registry. Game Platform still owns the WebView/runtime; AppShell only
/// broadcasts generic app/session resource pressure.
class RemoteGamePlayerPage extends ConsumerStatefulWidget {
  const RemoteGamePlayerPage({
    super.key,
    required this.gameId,
    this.roomId,
    this.embeddedInRoom = false,
  });

  final String gameId;
  final String? roomId;
  final bool embeddedInRoom;

  @override
  ConsumerState<RemoteGamePlayerPage> createState() =>
      _RemoteGamePlayerPageState();
}

class _RemoteGamePlayerPageState extends ConsumerState<RemoteGamePlayerPage> {
  VerifiedGameBundle? _bundle;
  GameRuntime? _runtime;
  GameHostBridge? _bridge;
  GameWebViewResourceParticipant? _resourceParticipant;
  MediaResourceRegistry? _resourceRegistry;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _detachRuntimeResource();
    final runtime = _runtime;
    if (runtime != null) unawaited(runtime.dispose());
    final bridge = _bridge;
    if (bridge != null) unawaited(bridge.dispose());
    super.dispose();
  }

  Future<void> _load() async {
    _detachRuntimeResource();
    final previous = _runtime;
    if (previous != null) {
      await previous.dispose();
    }
    final previousBridge = _bridge;
    if (previousBridge != null) {
      await previousBridge.dispose();
    }
    if (!mounted) return;

    setState(() {
      _runtime = null;
      _bridge = null;
      _bundle = null;
      _error = null;
      _loading = true;
    });

    try {
      final session = ref.read(sessionRepositoryProvider);
      final token = session.accessToken?.trim();
      if (token == null || token.isEmpty) {
        throw const GameManifestException(
          'Please sign in again before opening a game.',
        );
      }

      final bundle = await ref.read(gameManifestRepositoryProvider).load(
        widget.gameId,
      );
      if (!mounted) return;

      final bridge = GameHostBridge(
        api: ref.read(appNetworkClientProvider),
        accessToken: token,
        gameId: bundle.manifest.gameId,
        bridgeVersion: bundle.manifest.bridgeVersion,
        roomId: widget.roomId,
        onClose: _close,
      );
      await bridge.initialize();
      if (!mounted) {
        await bridge.dispose();
        return;
      }

      late final InAppWebViewGameRuntime runtime;
      runtime = InAppWebViewGameRuntime(
        bundle: bundle,
        bridge: bridge,
        onError: _showRuntimeError,
        onReady: () {
          unawaited(
            _attachRuntimeResource(runtime, bundle.manifest.cacheKey),
          );
        },
      );

      setState(() {
        _bundle = bundle;
        _bridge = bridge;
        _runtime = runtime;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _displayError(error);
      });
    }
  }

  Future<void> _attachRuntimeResource(
    GameRuntime runtime,
    String resourceKey,
  ) async {
    if (!mounted || !identical(_runtime, runtime)) return;
    if (_resourceParticipant != null) return;

    final registry = ref.read(mediaResourceRegistryProvider);
    if (registry == null) return;

    final participant = GameWebViewResourceParticipant(
      resourceId: 'game:webview:$resourceKey',
      runtime: runtime,
    );
    try {
      if (!registry.register(participant)) return;
      _resourceRegistry = registry;
      _resourceParticipant = participant;
      await participant.onForegroundChanged(registry.isForeground);
    } catch (error) {
      debugPrint('[FK:W:GameResource:Register] $error');
    }
  }

  void _detachRuntimeResource() {
    final registry = _resourceRegistry;
    final participant = _resourceParticipant;
    _resourceRegistry = null;
    _resourceParticipant = null;
    if (registry == null || participant == null) return;
    registry.unregister(
      participant.resourceId,
      expectedParticipant: participant,
    );
  }

  void _showRuntimeError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  void _close() {
    if (!mounted) return;
    Navigator.maybePop(context);
  }

  String _displayError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? 'Game unavailable.' : message;
  }

  @override
  Widget build(BuildContext context) {
    final runtime = _runtime;
    final bundle = _bundle;

    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(widget.embeddedInRoom ? 26 : 0),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF06140B),
        body: SafeArea(
          top: !widget.embeddedInRoom,
          child: _loading
              ? _GameLoadingView(onClose: _close)
              : _error != null
              ? _GameErrorView(
                  message: _error!,
                  onRetry: _load,
                  onClose: _close,
                )
              : runtime == null || bundle == null
              ? _GameErrorView(
                  message: 'Game unavailable.',
                  onRetry: _load,
                  onClose: _close,
                )
              : runtime.buildView(
                  key: ValueKey<String>(bundle.manifest.cacheKey),
                ),
        ),
      ),
    );
  }
}

class _GameLoadingView extends StatelessWidget {
  const _GameLoadingView({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFFD36A),
            strokeWidth: 2.4,
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _GameErrorView extends StatelessWidget {
  const _GameErrorView({
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

  final String message;
  final Future<void> Function() onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sports_esports_rounded,
                  color: Color(0xFFFFD36A),
                  size: 42,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Game unavailable',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => unawaited(onRetry()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
