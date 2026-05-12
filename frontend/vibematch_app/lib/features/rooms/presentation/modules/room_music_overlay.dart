
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
        if (state.isOverlayVisible) {
          return RoomMusicBottomOverlay(state: state);
        }

        if (state.isMinimized || state.isPlaying || state.isUploading) {
          return RoomMusicDiscBubble(state: state);
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class RoomMusicBottomOverlay extends StatelessWidget {
  const RoomMusicBottomOverlay({super.key, required this.state});

  final RoomMusicState state;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.30;
    final track = state.currentTrack;

    return Positioned(
      left: 10,
      right: 10,
      bottom: MediaQuery.paddingOf(context).bottom + 8,
      height: height.clamp(210.0, 310.0),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF090D16).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
                child: Row(
                  children: [
                    const _SpinningDisc(size: 42),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        track?.title ?? 'Room music',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Minimize',
                      onPressed: RoomMusicController.instance.minimizeOverlay,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                    ),
                    IconButton(
                      tooltip: 'Stop music',
                      onPressed: RoomMusicController.instance.stop,
                      icon: const Icon(Icons.stop_circle_rounded, color: Color(0xFFFF6D8D)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: RoomMusicController.instance.playPrevious,
                      icon: const Icon(Icons.skip_previous_rounded),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: state.isUploading
                          ? null
                          : RoomMusicController.instance.playCurrentOrFirst,
                      icon: state.isUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              state.isPlaying
                                  ? Icons.graphic_eq_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: RoomMusicController.instance.playNext,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => RoomMusicLibrarySheet.open(context),
                      icon: const Icon(Icons.library_music_rounded, size: 18),
                      label: const Text('Add'),
                    ),
                    TextButton.icon(
                      onPressed: state.playlist.isEmpty
                          ? null
                          : RoomMusicController.instance.clearPlaylist,
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              if (state.lastError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    state.lastError!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFF9AAE),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                  itemCount: state.playlist.length,
                  itemBuilder: (context, index) {
                    final item = state.playlist[index];
                    final active = index == state.currentIndex;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: active
                            ? RoomColors.aqua.withValues(alpha: 0.16)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        dense: true,
                        onTap: () => RoomMusicController.instance.playIndex(index),
                        leading: Icon(
                          active ? Icons.equalizer_rounded : Icons.music_note_rounded,
                          color: active ? RoomColors.aqua : Colors.white70,
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        trailing: IconButton(
                          onPressed: () => RoomMusicController.instance.removeTrack(item.id),
                          icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
                        ),
                      ),
                    );
                  },
                ),
              ),
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

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 14,
      bottom: MediaQuery.paddingOf(context).bottom + 86,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: RoomMusicController.instance.showOverlay,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1020).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: RoomColors.aqua.withValues(alpha: 0.45)),
                boxShadow: [
                  BoxShadow(
                    color: RoomColors.aqua.withValues(alpha: 0.25),
                    blurRadius: 22,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const _SpinningDisc(size: 42),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 92,
                    child: Text(
                      state.currentTrack?.title ?? 'Music',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: RoomMusicController.instance.stop,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFFFF4E78),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpinningDisc extends StatefulWidget {
  const _SpinningDisc({required this.size});

  final double size;

  @override
  State<_SpinningDisc> createState() => _SpinningDiscState();
}

class _SpinningDiscState extends State<_SpinningDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return Transform.rotate(
          angle: _controller.value * math.pi * 2,
          child: child,
        );
      },
      child: Container(
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
      ),
    );
  }
}
