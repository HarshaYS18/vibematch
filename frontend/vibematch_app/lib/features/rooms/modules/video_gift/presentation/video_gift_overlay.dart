import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../presentation/live_room_models.dart';
import '../../../presentation/widgets/room_theme.dart';

class VideoGiftOverlay extends StatelessWidget {
  const VideoGiftOverlay({
    super.key,
    required this.slides,
    required this.onVideoFinished,
  });

  final List<GiftSlide> slides;
  final ValueChanged<GiftSlide> onVideoFinished;

  @override
  Widget build(BuildContext context) {
    final activeVideoSlides = slides
        .where((slide) => slide.videoAssetPath?.trim().isNotEmpty ?? false)
        .take(1)
        .toList(growable: false);

    if (activeVideoSlides.isEmpty) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: Center(
          child: VideoGiftCard(
            slide: activeVideoSlides.first,
            onVideoFinished: onVideoFinished,
          ),
        ),
      ),
    );
  }
}

class VideoGiftCard extends StatefulWidget {
  const VideoGiftCard({
    super.key,
    required this.slide,
    required this.onVideoFinished,
  });

  final GiftSlide slide;
  final ValueChanged<GiftSlide> onVideoFinished;

  @override
  State<VideoGiftCard> createState() => _VideoGiftCardState();
}

class _VideoGiftCardState extends State<VideoGiftCard> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _finishNotified = false;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  @override
  void didUpdateWidget(covariant VideoGiftCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slide.id != widget.slide.id) {
      _disposeController();
      _ready = false;
      _failed = false;
      _finishNotified = false;
      _loadVideo();
    }
  }

  Future<void> _loadVideo() async {
    final path = widget.slide.videoAssetPath;
    if (path == null || path.trim().isEmpty) return;

    try {
      final controller = VideoPlayerController.asset(path);
      _controller = controller;
      controller.addListener(_handlePlaybackState);
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(1.0);
      await controller.play();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
      _notifyFinished();
    }
  }

  void _handlePlaybackState() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final value = controller.value;
    final duration = value.duration;
    final position = value.position;
    if (duration == Duration.zero) return;

    final nearEnd = position >= duration - const Duration(milliseconds: 120);
    if (nearEnd && !value.isPlaying) {
      _notifyFinished();
      return;
    }
    if (nearEnd) {
      Future<void>.delayed(const Duration(milliseconds: 160), () {
        if (!mounted) return;
        final latest = _controller;
        if (latest == null || !latest.value.isInitialized) return;
        if (latest.value.position >= latest.value.duration - const Duration(milliseconds: 80)) {
          _notifyFinished();
        }
      });
    }
  }

  void _notifyFinished() {
    if (_finishNotified) return;
    _finishNotified = true;
    widget.onVideoFinished(widget.slide);
  }

  void _disposeController() {
    final controller = _controller;
    if (controller == null) return;
    controller.removeListener(_handlePlaybackState);
    controller.pause();
    controller.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cardWidth = (size.width * 0.82).clamp(280.0, 390.0);
    final cardHeight = (size.height * 0.40).clamp(250.0, 360.0);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.88, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(scale: value, child: child),
        );
      },
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          boxShadow: [
            BoxShadow(
              color: RoomColors.coral.withValues(alpha: 0.32),
              blurRadius: 34,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: RoomColors.gold.withValues(alpha: 0.20),
              blurRadius: 44,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(27),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_ready && _controller != null)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                )
              else
                _VideoGiftFallback(
                  failed: _failed,
                  colors: widget.slide.colors,
                  icon: widget.slide.giftIcon,
                ),
              Positioned(
                left: 12,
                right: 12,
                top: 12,
                child: _VideoGiftTitle(slide: widget.slide),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoGiftTitle extends StatelessWidget {
  const _VideoGiftTitle({required this.slide});

  final GiftSlide slide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              slide.senderName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 7),
            child: Text(
              '➜',
              style: TextStyle(
                color: RoomColors.gold,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Flexible(
            child: Text(
              slide.receiverName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            'x${slide.combo}',
            style: const TextStyle(
              color: RoomColors.gold,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoGiftFallback extends StatelessWidget {
  const _VideoGiftFallback({
    required this.failed,
    required this.colors,
    required this.icon,
  });

  final bool failed;
  final List<Color> colors;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 58),
            const SizedBox(height: 12),
            Text(
              failed ? 'Video file missing' : 'Loading effect...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
