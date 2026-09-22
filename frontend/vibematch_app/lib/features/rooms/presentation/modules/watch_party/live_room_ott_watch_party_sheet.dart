import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../foundation/di/app_dependencies.dart';
import '../../../../../room_session/data/room_session_repository.dart';
import '../../../../../session/data/session_repository.dart';
import '../../../../../watch_party/application/watch_party_coordinator.dart';
import '../../../../../watch_party/data/watch_party_repository.dart';
import '../../../../../watch_party/domain/watch_party_state.dart';
import '../../../../../watch_party/domain/watch_provider_adapter.dart';
import '../../../../../watch_party/providers/jiohotstar/jiohotstar_provider_adapter.dart';
import '../../../../../watch_party/providers/netflix/netflix_provider_adapter.dart';
import '../../../../../watch_party/providers/prime_video/prime_video_provider_adapter.dart';
import '../../../../../watch_party/providers/web/ott_provider_definition.dart';
import '../../../../../watch_party/providers/web/supported_web_playback_adapter.dart';
import '../../live_room_models.dart';
import '../../widgets/room_theme.dart';

class LiveRoomOttWatchPartySheet extends ConsumerStatefulWidget {
  const LiveRoomOttWatchPartySheet({
    super.key,
    required this.roomId,
    required this.canManageRoom,
    required this.privacyMode,
    required this.provider,
    this.onBackToProviders,
  });

  final String roomId;
  final bool canManageRoom;
  final RoomPrivacyMode privacyMode;
  final OttProviderDefinition provider;
  final VoidCallback? onBackToProviders;

  @override
  ConsumerState<LiveRoomOttWatchPartySheet> createState() =>
      _LiveRoomOttWatchPartySheetState();
}

class _LiveRoomOttWatchPartySheetState
    extends ConsumerState<LiveRoomOttWatchPartySheet>
    with WidgetsBindingObserver {
  late final SupportedWebPlaybackAdapter _adapter;
  late final WatchPartyCoordinator _coordinator;
  late final TextEditingController _contentController;

  Timer? _syncTimer;
  WatchPartyState? _latestState;
  String? _lastImmediateFingerprint;
  String? _localError;
  bool _busy = false;
  bool _liveMode = false;
  bool _resuming = false;

  bool get _privateRoom => widget.privacyMode == RoomPrivacyMode.privateVibe;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _contentController = TextEditingController();
    _adapter = _buildAdapter(widget.provider);
    _coordinator = WatchPartyCoordinator(adapter: _adapter);
    _syncTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_reconcileLatest()),
    );
  }

  SupportedWebPlaybackAdapter _buildAdapter(OttProviderDefinition provider) {
    final telemetry = ref.read(appTelemetryProvider);
    if (provider.id == OttProviderCatalog.netflix.id) {
      return NetflixProviderAdapter(telemetry: telemetry);
    }
    if (provider.id == OttProviderCatalog.primeVideo.id) {
      return PrimeVideoProviderAdapter(telemetry: telemetry);
    }
    if (provider.id == OttProviderCatalog.jioHotstar.id) {
      return JioHotstarProviderAdapter(telemetry: telemetry);
    }
    throw StateError('Unsupported OTT provider: ${provider.id}');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_restoreAfterExternalProvider());
    }
  }

  Future<void> _restoreAfterExternalProvider() async {
    if (_resuming || !mounted) return;
    _resuming = true;
    try {
      await ref
          .read(roomSessionRepositoryProvider(widget.roomId).notifier)
          .refreshSnapshot(force: true);
      await _adapter.restoreAfterExternalLaunch();
      await _reconcileLatest();
    } catch (_) {
      // The canonical repositories expose any meaningful state error.
    } finally {
      _resuming = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _contentController.dispose();
    unawaited(_coordinator.dispose());
    super.dispose();
  }

  Future<void> _reconcileLatest() async {
    final state = _latestState;
    final session = state?.session;
    if (state == null ||
        session == null ||
        !session.active ||
        session.provider.trim().toLowerCase() != widget.provider.id) {
      return;
    }
    try {
      await _coordinator.reconcile(state);
      if (mounted && _localError != null) {
        setState(() => _localError = null);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _localError = _cleanError(error));
    }
  }

  void _scheduleImmediateReconcile(WatchPartyState state) {
    final session = state.session;
    if (session == null ||
        !session.active ||
        session.provider.trim().toLowerCase() != widget.provider.id) {
      return;
    }
    final fingerprint =
        '${session.sessionId}|${session.revision}|${state.serverTimeMs}';
    if (_lastImmediateFingerprint == fingerprint) return;

    // Keep the editor aligned with the canonical active session. Local toggle
    // changes remain local until a command is submitted, but reopening or a
    // canonical revision never silently resets a live session to VOD.
    _liveMode = session.isLive;
    _lastImmediateFingerprint = fingerprint;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_reconcileLatest());
    });
  }

  Future<void> _submitContent({required bool changeExisting}) async {
    if (!_privateRoom) {
      setState(() {
        _localError =
            'OTT Watch Party requires a Private Vibe invite-only room.';
      });
      return;
    }

    final uri = widget.provider.normalizeContentInput(
      _contentController.text,
    );
    if (uri == null) {
      setState(() {
        _localError =
            'Enter a valid ${widget.provider.displayName} HTTPS content link.';
      });
      return;
    }

    final timelineMode =
        _liveMode && widget.provider.liveContentSupported
            ? WatchTimelineMode.live
            : WatchTimelineMode.vod;

    await _runCommand(() {
      final repository = ref.read(
        watchPartyRepositoryProvider(widget.roomId).notifier,
      );
      if (changeExisting) {
        return repository.changeContent(
          provider: widget.provider.id,
          contentUrl: uri.toString(),
          contentTitle: widget.provider.displayName,
          positionMs: 0,
          timelineMode: timelineMode,
          targetLiveLatencyMs: defaultWatchTargetLiveLatencyMs,
        );
      }
      return repository.load(
        provider: widget.provider.id,
        contentUrl: uri.toString(),
        contentTitle: widget.provider.displayName,
        positionMs: 0,
        timelineMode: timelineMode,
        targetLiveLatencyMs: defaultWatchTargetLiveLatencyMs,
      );
    });

    if (mounted && _localError == null) {
      _contentController.clear();
    }
  }

  Future<void> _togglePlayback(WatchSession session) {
    return _runCommand(() {
      final repository = ref.read(
        watchPartyRepositoryProvider(widget.roomId).notifier,
      );
      return session.playbackState == WatchPlaybackState.playing
          ? repository.pause()
          : repository.play();
    });
  }

  Future<void> _seekRelative(int deltaSeconds) async {
    try {
      final localMs = await _adapter.currentPositionMs();
      final targetMs =
          (localMs + deltaSeconds * 1000).clamp(0, 1 << 62).toInt();
      await _runCommand(
        () => ref
            .read(watchPartyRepositoryProvider(widget.roomId).notifier)
            .seek(targetMs),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _localError = _cleanError(error));
    }
  }

  Future<void> _resyncLive(WatchSession session) {
    return _runCommand(
      () => ref
          .read(watchPartyRepositoryProvider(widget.roomId).notifier)
          .sync(
            positionMs: session.positionMs,
            playbackState: WatchPlaybackState.playing,
            playbackRate: 1,
          ),
    );
  }

  Future<void> _endParty() {
    return _runCommand(
      () => ref
          .read(watchPartyRepositoryProvider(widget.roomId).notifier)
          .end(),
    );
  }

  Future<void> _retryEmbedded() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      final ready = await _adapter.retryEmbeddedProbe(
        fallbackIfUnavailable: false,
      );
      if (!ready && mounted) {
        setState(() {
          _localError =
              'Embedded playback is not ready. Sign in or start playback in the provider page, then retry.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _localError = _cleanError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useCompanionAndOpen() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      _adapter.useCompanionFallback();
      final launched = await _adapter.launchExternal();
      if (!launched && mounted) {
        setState(() {
          _localError =
              'Could not open ${widget.provider.displayName} on this device.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _localError = _cleanError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runCommand(
    Future<WatchPartyState> Function() command,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      await command();
    } catch (error) {
      if (!mounted) return;
      setState(() => _localError = _cleanError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final watchState = ref.watch(
      watchPartyRepositoryProvider(widget.roomId),
    );
    final signedInUserId = ref.watch(
      sessionRepositoryProvider.select((state) => state.signedInUserId),
    );
    _latestState = watchState;
    _scheduleImmediateReconcile(watchState);

    final session = watchState.session;
    final active =
        watchState.active &&
        session?.provider.trim().toLowerCase() == widget.provider.id;
    final canControl =
        widget.canManageRoom ||
        (session != null &&
            signedInUserId != null &&
            session.controllerUserId == signedInUserId);
    final error = _localError ?? watchState.errorMessage;

    return ValueListenableBuilder<OttProviderRuntimeState>(
      valueListenable: _adapter.runtimeState,
      builder: (context, runtime, _) {
        final capabilities = _adapter.capabilities;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.90,
          ),
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            MediaQuery.paddingOf(context).bottom + 16,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (widget.onBackToProviders != null) ...[
                      IconButton(
                        tooltip: 'Providers',
                        onPressed: widget.onBackToProviders,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 2),
                    ],
                    Expanded(
                      child: Text(
                        '${widget.provider.displayName} Watch Party',
                        style: const TextStyle(
                          color: RoomColors.plum,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (active && canControl)
                      TextButton(
                        onPressed:
                            _busy ? null : () => unawaited(_endParty()),
                        child: const Text('End'),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  active
                      ? 'Synchronized by the room timeline'
                      : 'Desktop-style WebView is tried first; companion mode is the safe fallback.',
                  style: const TextStyle(
                    color: Color(0xFF7B6A86),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                if (!_privateRoom) ...[
                  const SizedBox(height: 12),
                  const _OttPrivacyBanner(),
                ],
                if (error != null && error.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _OttErrorBanner(message: error),
                ],
                if (active && session != null) ...[
                  const SizedBox(height: 14),
                  _RuntimeSurface(
                    providerName: widget.provider.displayName,
                    adapter: _adapter,
                    runtime: runtime,
                    busy: _busy,
                    onRetryEmbedded: () => unawaited(_retryEmbedded()),
                    onUseCompanion: () =>
                        unawaited(_useCompanionAndOpen()),
                  ),
                  const SizedBox(height: 12),
                  _PlaybackControls(
                    session: session,
                    capabilities: capabilities,
                    canControl: canControl,
                    busy: _busy,
                    onTogglePlayback: () =>
                        unawaited(_togglePlayback(session)),
                    onSeekBack: () => unawaited(_seekRelative(-10)),
                    onSeekForward: () => unawaited(_seekRelative(10)),
                    onResyncLive: () =>
                        unawaited(_resyncLive(session)),
                    onOpenProvider: () =>
                        unawaited(_useCompanionAndOpen()),
                  ),
                ],
                if ((!active && widget.canManageRoom) ||
                    (active && canControl)) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contentController,
                    enabled: !_busy && _privateRoom,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: active
                          ? 'Change ${widget.provider.displayName} content'
                          : '${widget.provider.displayName} content link',
                      hintText: widget.provider.homeUri.toString(),
                      filled: true,
                      fillColor: RoomColors.pearl,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: RoomColors.softLine),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: RoomColors.softLine),
                      ),
                    ),
                    onSubmitted: (_) {
                      if (_busy || !_privateRoom) return;
                      unawaited(
                        _submitContent(changeExisting: active),
                      );
                    },
                  ),
                  if (widget.provider.liveContentSupported) ...[
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _liveMode,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _liveMode = value),
                      title: const Text(
                        'Live event / sports',
                        style: TextStyle(
                          color: RoomColors.plum,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: const Text(
                        'Targets about 10 seconds behind the available live edge.',
                        style: TextStyle(
                          color: Color(0xFF7B6A86),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy || !_privateRoom
                          ? null
                          : () => unawaited(
                              _submitContent(changeExisting: active),
                            ),
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_circle_fill_rounded),
                      label: Text(
                        active ? 'Change content' : 'Start Watch Party',
                      ),
                    ),
                  ),
                ],
                if (!active && !widget.canManageRoom) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'The room host or admin can start the Watch Party.',
                    style: TextStyle(
                      color: Color(0xFF7B6A86),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RuntimeSurface extends StatelessWidget {
  const _RuntimeSurface({
    required this.providerName,
    required this.adapter,
    required this.runtime,
    required this.busy,
    required this.onRetryEmbedded,
    required this.onUseCompanion,
  });

  final String providerName;
  final SupportedWebPlaybackAdapter adapter;
  final OttProviderRuntimeState runtime;
  final bool busy;
  final VoidCallback onRetryEmbedded;
  final VoidCallback onUseCompanion;

  @override
  Widget build(BuildContext context) {
    if (runtime.mode == OttRuntimeMode.companion) {
      return _CompanionCard(
        providerName: providerName,
        reason: runtime.errorCode,
        busy: busy,
        onOpen: onUseCompanion,
        onRetry: onRetryEmbedded,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ColoredBox(
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: adapter.buildWebView(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              runtime.mode == OttRuntimeMode.embedded
                  ? Icons.check_circle_rounded
                  : Icons.sync_rounded,
              size: 16,
              color: runtime.mode == OttRuntimeMode.embedded
                  ? RoomColors.aqua
                  : RoomColors.gold,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                runtime.mode == OttRuntimeMode.embedded
                    ? 'Embedded playback capability verified on this device.'
                    : _runtimeHint(runtime.errorCode),
                style: const TextStyle(
                  color: Color(0xFF7B6A86),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        if (runtime.mode == OttRuntimeMode.probing) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onRetryEmbedded,
                  child: const Text('Retry embedded'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: busy ? null : onUseCompanion,
                  child: const Text('Use companion'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _runtimeHint(String? code) {
    switch (code) {
      case 'LOGIN_REQUIRED_OR_PLAYER_UNAVAILABLE':
        return 'Sign in with your own provider account and start the content, then retry embedded playback.';
      case 'PROTECTED_CONTENT_NOT_READY':
        return 'The page loaded, but protected playback is not ready yet.';
      case 'PAGE_LOAD_TIMEOUT':
        return 'The provider page did not become ready in time.';
      default:
        return 'Checking whether real embedded playback works on this device.';
    }
  }
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.session,
    required this.capabilities,
    required this.canControl,
    required this.busy,
    required this.onTogglePlayback,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onResyncLive,
    required this.onOpenProvider,
  });

  final WatchSession session;
  final WatchProviderCapabilities capabilities;
  final bool canControl;
  final bool busy;
  final VoidCallback onTogglePlayback;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onResyncLive;
  final VoidCallback onOpenProvider;

  @override
  Widget build(BuildContext context) {
    if (!capabilities.embeddedPlayback) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: busy ? null : onOpenProvider,
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Open provider'),
        ),
      );
    }

    if (session.isLive) {
      if (!canControl) {
        return const Text(
          'Following the room live target.',
          style: TextStyle(
            color: Color(0xFF7B6A86),
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        );
      }
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed:
              busy || !capabilities.liveResync ? null : onResyncLive,
          icon: const Icon(Icons.sync_rounded),
          label: const Text('Resync room to live target'),
        ),
      );
    }

    if (!canControl) {
      return const Text(
        'Following the room controller.',
        style: TextStyle(
          color: Color(0xFF7B6A86),
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return Row(
      children: [
        IconButton(
          tooltip: 'Back 10 seconds',
          onPressed:
              busy || !capabilities.manualSeek ? null : onSeekBack,
          icon: const Icon(Icons.replay_10_rounded),
        ),
        Expanded(
          child: FilledButton.icon(
            onPressed:
                busy || !capabilities.manualPlayPause
                    ? null
                    : onTogglePlayback,
            icon: Icon(
              session.playbackState == WatchPlaybackState.playing
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
            label: Text(
              session.playbackState == WatchPlaybackState.playing
                  ? 'Pause'
                  : 'Play',
            ),
          ),
        ),
        IconButton(
          tooltip: 'Forward 10 seconds',
          onPressed:
              busy || !capabilities.manualSeek ? null : onSeekForward,
          icon: const Icon(Icons.forward_10_rounded),
        ),
      ],
    );
  }
}

class _CompanionCard extends StatelessWidget {
  const _CompanionCard({
    required this.providerName,
    required this.reason,
    required this.busy,
    required this.onOpen,
    required this.onRetry,
  });

  final String providerName;
  final String? reason;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RoomColors.pearl,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RoomColors.softLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.devices_rounded, color: RoomColors.plum, size: 20),
              SizedBox(width: 8),
              Text(
                'Companion mode',
                style: TextStyle(
                  color: RoomColors.plum,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Embedded playback is unavailable on this device${reason == null ? '' : ' ($reason)'}. Open $providerName with your own account while FunKey keeps the room timeline, voice, chat and seats.',
            style: const TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : onOpen,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text('Open $providerName'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: busy ? null : onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OttPrivacyBanner extends StatelessWidget {
  const _OttPrivacyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RoomColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: RoomColors.gold.withValues(alpha: 0.30),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_rounded, color: RoomColors.plum, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Switch this room to Private Vibe before starting OTT Watch Party. The backend enforces this rule.',
              style: TextStyle(
                color: RoomColors.plum,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OttErrorBanner extends StatelessWidget {
  const _OttErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: RoomColors.coral.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: RoomColors.coral.withValues(alpha: 0.20),
        ),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: RoomColors.coral,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
      ),
    );
  }
}
