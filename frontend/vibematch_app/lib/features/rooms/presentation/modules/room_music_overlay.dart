import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/room_music_controller.dart';
import 'room_music_library_sheet.dart';
import '../widgets/room_theme.dart';

class RoomMusicOverlayHost extends StatelessWidget {
  const RoomMusicOverlayHost({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RoomMusicState>(
      valueListenable: RoomMusicController.instance.state,
      builder: (context, state, _) {
        final children = <Widget>[];

        if (state.isOverlayVisible) {
          children.add(
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: RoomMusicController.instance.minimizeOverlay,
                child: const SizedBox.expand(),
              ),
            ),
          );
          children.add(RoomMusicBottomOverlay(state: state));
        } else if (state.isMinimized || state.isPlaying || state.isUploading || state.isPaused) {
          children.add(RoomMusicDiscBubble(state: state));
        }

        if (children.isEmpty) return const SizedBox.shrink();
        return Stack(children: children);
      },
    );
  }
}

class RoomMusicBottomOverlay extends StatefulWidget {
  const RoomMusicBottomOverlay({super.key, required this.state});

  final RoomMusicState state;

  @override
  State<RoomMusicBottomOverlay> createState() => _RoomMusicBottomOverlayState();
}

class _RoomMusicBottomOverlayState extends State<RoomMusicBottomOverlay> {
  double? _dragValue;

  String _timeLabel(int ms) {
    if (ms <= 0) return '0:00';
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final track = state.currentTrack;
    final durationMs = state.durationMs;
    final positionMs = state.positionMs;
    final sliderMax = durationMs <= 0 ? 1.0 : durationMs.toDouble();
    final sliderValue = (_dragValue ?? positionMs.toDouble()).clamp(0.0, sliderMax);

    return Positioned(
      left: 12,
      right: 12,
      bottom: MediaQuery.paddingOf(context).bottom + 76,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 178),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xF20A1020), Color(0xF2181230), Color(0xF20D2330)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.50),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: RoomColors.aqua.withValues(alpha: 0.18),
                blurRadius: 28,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _SpinningDisc(
                    size: 44,
                    active: state.isPlaying || state.isUploading,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => RoomMusicLibrarySheet.open(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track?.title ?? 'Room Music',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            track == null
                                ? 'Add songs to start'
                                : state.isUploading
                                    ? 'Preparing room broadcast...'
                                    : state.isPaused
                                        ? 'Paused'
                                        : state.isPlaying
                                            ? 'Playing to everyone'
                                            : '${state.playlist.length} songs added',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.62),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Add songs',
                    onPressed: () => RoomMusicLibrarySheet.open(context),
                    icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Minimize',
                    onPressed: RoomMusicController.instance.minimizeOverlay,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    _timeLabel(positionMs),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        value: sliderValue,
                        min: 0,
                        max: sliderMax,
                        onChanged: durationMs <= 0
                            ? null
                            : (value) {
                                setState(() => _dragValue = value);
                                RoomMusicController.instance.previewSeekPosition(value.round());
                              },
                        onChangeEnd: durationMs <= 0
                            ? null
                            : (value) async {
                                final seekValue = value.round();
                                setState(() => _dragValue = null);
                                await RoomMusicController.instance.seekTo(seekValue);
                              },
                      ),
                    ),
                  ),
                  Text(
                    durationMs <= 0 ? '--:--' : _timeLabel(durationMs),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundControlButton(
                    icon: Icons.skip_previous_rounded,
                    onTap: RoomMusicController.instance.playPrevious,
                  ),
                  const SizedBox(width: 12),
                  _MainControlButton(
                    loading: state.isUploading,
                    playing: state.isPlaying,
                    paused: state.isPaused,
                    onTap: () {
                      if (state.isUploading) return;
                      if (state.isPlaying) {
                        RoomMusicController.instance.pause();
                      } else {
                        RoomMusicController.instance.playCurrentOrFirst();
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  _RoundControlButton(
                    icon: Icons.skip_next_rounded,
                    onTap: RoomMusicController.instance.playNext,
                  ),
                  const SizedBox(width: 18),
                  _RoundControlButton(
                    icon: Icons.stop_rounded,
                    danger: true,
                    onTap: RoomMusicController.instance.stop,
                  ),
                ],
              ),
              if (state.lastError != null) ...[
                const SizedBox(height: 6),
                Text(
                  state.lastError!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFF9AAE),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class RoomMusicDiscBubble extends StatelessWidget {
  const RoomMusicDiscBubble({super.key, required this.state});

  final RoomMusicState state;

  Offset _defaultOffset(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Offset(size.width - 92, size.height - 210);
  }

  Offset _clampOffset(BuildContext context, Offset value) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final maxX = math.max(8.0, size.width - 88);
    final maxY = math.max(padding.top + 8, size.height - padding.bottom - 130);
    return Offset(
      value.dx.clamp(8.0, maxX),
      value.dy.clamp(padding.top + 8, maxY),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offset = _clampOffset(context, state.bubbleOffset ?? _defaultOffset(context));

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          RoomMusicController.instance.setBubbleOffset(
            _clampOffset(context, offset + details.delta),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: RoomMusicController.instance.showOverlay,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xF20B1020),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: RoomColors.aqua.withValues(alpha: 0.50),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: RoomColors.aqua.withValues(alpha: 0.28),
                        blurRadius: 22,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.42),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _SpinningDisc(
                      size: 42,
                      active: state.isPlaying || state.isUploading,
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(-9, -20),
                child: GestureDetector(
                  onTap: RoomMusicController.instance.stop,
                  child: Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4E78),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundControlButton extends StatelessWidget {
  const _RoundControlButton({
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: danger
            ? const Color(0xFFFF4E78).withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.10),
        foregroundColor: danger ? const Color(0xFFFF6D8D) : Colors.white,
        shape: const CircleBorder(),
      ),
      icon: Icon(icon, size: 24),
    );
  }
}

class _MainControlButton extends StatelessWidget {
  const _MainControlButton({
    required this.loading,
    required this.playing,
    required this.paused,
    required this.onTap,
  });

  final bool loading;
  final bool playing;
  final bool paused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 54,
      child: FilledButton(
        onPressed: loading ? null : onTap,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          backgroundColor: RoomColors.aqua,
          foregroundColor: const Color(0xFF061015),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.3),
              )
            : Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 32,
              ),
      ),
    );
  }
}

class _SpinningDisc extends StatefulWidget {
  const _SpinningDisc({
    required this.size,
    required this.active,
  });

  final double size;
  final bool active;

  @override
  State<_SpinningDisc> createState() => _SpinningDiscState();
}

class _SpinningDiscState extends State<_SpinningDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _SpinningDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disc = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [
            Color(0xFF15151F),
            Color(0xFF42F5E8),
            Color(0xFF7C4DFF),
            Color(0xFFFF6D8D),
            Color(0xFF15151F),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: widget.size * 0.34,
          height: widget.size * 0.34,
          decoration: const BoxDecoration(
            color: Color(0xFF05070F),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: widget.size * 0.12,
              height: widget.size * 0.12,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return Transform.rotate(
          angle: _controller.value * math.pi * 2,
          child: child,
        );
      },
      child: disc,
    );
  }
}
