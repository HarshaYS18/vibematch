import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../../../session/data/session_repository.dart';
import '../../../../../watch_party/application/watch_party_coordinator.dart';
import '../../../../../watch_party/data/watch_party_repository.dart';
import '../../../../../watch_party/domain/watch_party_state.dart';
import '../../../../../watch_party/providers/youtube/youtube_content_id.dart';
import '../../../../../watch_party/providers/youtube/youtube_player_port.dart';
import '../../../../../watch_party/providers/youtube/youtube_watch_adapter.dart';
import '../../widgets/room_theme.dart';

class LiveRoomYoutubeWatchPartySheet extends ConsumerStatefulWidget {
  const LiveRoomYoutubeWatchPartySheet({
    super.key,
    required this.roomId,
    required this.canManageRoom,
  });

  final String roomId;
  final bool canManageRoom;

  @override
  ConsumerState<LiveRoomYoutubeWatchPartySheet> createState() =>
      _LiveRoomYoutubeWatchPartySheetState();
}

class _LiveRoomYoutubeWatchPartySheetState
    extends ConsumerState<LiveRoomYoutubeWatchPartySheet> {
  late final YoutubePlayerController _controller;
  late final WatchPartyCoordinator _coordinator;
  late final TextEditingController _contentController;
  Timer? _syncTimer;
  WatchPartyState? _latestState;
  String? _lastImmediateFingerprint;
  String? _localError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();
    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        enableJavaScript: true,
        playsInline: true,
        privacyEnhancedMode: true,
        videoStateUpdateInterval: 250,
      ),
      onWebResourceError: (_) {
        if (!mounted) return;
        setState(() {
          _localError = 'YouTube player could not be loaded on this device.';
        });
      },
    );
    _coordinator = WatchPartyCoordinator(
      adapter: YoutubeWatchAdapter(
        player: YoutubeIFramePlayerPort(_controller),
      ),
    );
    _syncTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_reconcileLatest()),
    );
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _contentController.dispose();
    unawaited(_coordinator.dispose());
    super.dispose();
  }

  Future<void> _reconcileLatest() async {
    final state = _latestState;
    if (state == null) return;
    final session = state.session;
    if (session != null &&
        session.active &&
        session.provider.trim().toLowerCase() != 'youtube') {
      return;
    }

    try {
      await _coordinator.reconcile(state);
      if (mounted && _localError != null) {
        setState(() => _localError = null);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _localError = _cleanError(error);
      });
    }
  }

  void _scheduleImmediateReconcile(WatchPartyState state) {
    final session = state.session;
    final fingerprint =
        '${session?.sessionId ?? 'none'}|${session?.revision ?? -1}|'
        '${state.serverTimeMs}';
    if (_lastImmediateFingerprint == fingerprint) return;
    _lastImmediateFingerprint = fingerprint;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_reconcileLatest());
    });
  }

  Future<void> _submitContent({
    required bool changeExisting,
  }) async {
    final raw = _contentController.text.trim();
    final videoId = YouTubeContentId.tryParse(raw);
    if (videoId == null) {
      setState(() {
        _localError = 'Enter a valid YouTube link or video ID.';
      });
      return;
    }

    await _runCommand(() {
      final repository = ref.read(
        watchPartyRepositoryProvider(widget.roomId).notifier,
      );
      if (changeExisting) {
        return repository.changeContent(
          provider: 'youtube',
          contentId: videoId,
          contentUrl: raw,
          positionMs: 0,
        );
      }
      return repository.load(
        provider: 'youtube',
        contentId: videoId,
        contentUrl: raw,
        positionMs: 0,
      );
    });

    if (mounted && _localError == null) {
      _contentController.clear();
    }
  }

  Future<void> _togglePlayback(WatchSession session) async {
    await _runCommand(() {
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
      final localSeconds = await _controller.currentTime;
      final targetMs =
          ((localSeconds * 1000).round() + deltaSeconds * 1000)
              .clamp(0, 1 << 62)
              .toInt();
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

  Future<void> _endParty() {
    return _runCommand(
      () => ref
          .read(watchPartyRepositoryProvider(widget.roomId).notifier)
          .end(),
    );
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
      if (mounted) {
        setState(() => _busy = false);
      }
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
    final active = watchState.active;
    final isYoutube =
        active && session?.provider.trim().toLowerCase() == 'youtube';
    final canControl =
        widget.canManageRoom ||
        (session != null &&
            signedInUserId != null &&
            session.controllerUserId == signedInUserId);
    final error = _localError ?? watchState.errorMessage;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
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
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Watch Party',
                    style: TextStyle(
                      color: RoomColors.plum,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (active && canControl)
                  TextButton(
                    onPressed: _busy ? null : () => unawaited(_endParty()),
                    child: const Text('End'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              active
                  ? 'Synchronized by the room timeline'
                  : 'Start a synchronized YouTube watch party',
              style: const TextStyle(
                color: Color(0xFF7B6A86),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (error != null && error.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: error),
            ],
            if (isYoutube) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ColoredBox(
                  color: Colors.black,
                  child: YoutubePlayer(
                    controller: _controller,
                    aspectRatio: 16 / 9,
                    keepAlive: true,
                    autoFullScreen: false,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _PlaybackStatus(
                controller: _controller,
                session: session!,
                canControl: canControl,
                busy: _busy,
                onTogglePlayback: () => unawaited(_togglePlayback(session)),
                onSeekBack: () => unawaited(_seekRelative(-10)),
                onSeekForward: () => unawaited(_seekRelative(10)),
                onFullscreen: _controller.enterFullScreen,
              ),
            ] else if (active) ...[
              const SizedBox(height: 16),
              Text(
                'This room is using ${session?.provider ?? 'another provider'}. '
                'Its playback adapter is handled in the next provider chunk.',
                style: const TextStyle(
                  color: Color(0xFF7B6A86),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
            if ((!active && widget.canManageRoom) ||
                (active && isYoutube && canControl)) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _contentController,
                enabled: !_busy,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: active
                      ? 'Change YouTube video'
                      : 'YouTube link or video ID',
                  hintText: 'https://youtube.com/watch?v=...',
                  filled: true,
                  fillColor: RoomColors.pearl,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: RoomColors.softLine),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: RoomColors.softLine),
                  ),
                ),
                onSubmitted: (_) {
                  if (_busy) return;
                  unawaited(_submitContent(changeExisting: active));
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy
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
                      : const Icon(Icons.smart_display_rounded),
                  label: Text(active ? 'Change video' : 'Start Watch Party'),
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
  }
}

class _PlaybackStatus extends StatelessWidget {
  const _PlaybackStatus({
    required this.controller,
    required this.session,
    required this.canControl,
    required this.busy,
    required this.onTogglePlayback,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onFullscreen,
  });

  final YoutubePlayerController controller;
  final WatchSession session;
  final bool canControl;
  final bool busy;
  final VoidCallback onTogglePlayback;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<YoutubeVideoState>(
      stream: controller.videoStateStream,
      builder: (context, snapshot) {
        final position = snapshot.data?.position ?? Duration.zero;
        final duration = controller.metadata.duration;
        return Column(
          children: [
            Row(
              children: [
                Text(
                  _format(position),
                  style: const TextStyle(
                    color: RoomColors.plum,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  duration > Duration.zero ? _format(duration) : '--:--',
                  style: const TextStyle(
                    color: Color(0xFF7B6A86),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (canControl)
                  IconButton(
                    onPressed: busy ? null : onSeekBack,
                    tooltip: 'Back 10 seconds',
                    icon: const Icon(Icons.replay_10_rounded),
                  ),
                if (canControl)
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onTogglePlayback,
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
                if (canControl)
                  IconButton(
                    onPressed: busy ? null : onSeekForward,
                    tooltip: 'Forward 10 seconds',
                    icon: const Icon(Icons.forward_10_rounded),
                  ),
                IconButton(
                  onPressed: onFullscreen,
                  tooltip: 'Fullscreen',
                  icon: const Icon(Icons.fullscreen_rounded),
                ),
              ],
            ),
            if (!canControl)
              const Text(
                'Playback follows the room controller.',
                style: TextStyle(
                  color: Color(0xFF7B6A86),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        );
      },
    );
  }

  static String _format(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: RoomColors.coral.withValues(alpha: 0.10),
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
        ),
      ),
    );
  }
}
