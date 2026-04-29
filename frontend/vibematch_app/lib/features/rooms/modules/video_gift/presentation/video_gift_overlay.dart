import 'dart:async';

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
        child: VideoGiftCard(
          slide: activeVideoSlides.first,
          onVideoFinished: onVideoFinished,
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
  Timer? _imageGiftTimer;
  bool _ready = false;
  bool _failed = false;
  bool _finishNotified = false;

  bool get _isAnimatedImageGift {
    final path = widget.slide.videoAssetPath?.toLowerCase().trim() ?? '';
    return path.endsWith('.webp') ||
        path.endsWith('.gif') ||
        path.endsWith('.png') ||
        path.endsWith('.apng');
  }

  @override
  void initState() {
    super.initState();
    _loadGiftEffect();
  }

  @override
  void didUpdateWidget(covariant VideoGiftCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slide.id != widget.slide.id ||
        oldWidget.slide.videoAssetPath != widget.slide.videoAssetPath) {
      _disposeController();
      _imageGiftTimer?.cancel();
      _imageGiftTimer = null;
      _ready = false;
      _failed = false;
      _finishNotified = false;
      _loadGiftEffect();
    }
  }

  void _loadGiftEffect() {
    if (_isAnimatedImageGift) {
      setState(() => _ready = true);
      _imageGiftTimer = Timer(const Duration(seconds: 8), _notifyFinished);
      return;
    }
    unawaited(_loadVideo());
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
    _imageGiftTimer?.cancel();
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final safeTop = MediaQuery.paddingOf(context).top;
    final effectWidth = screen.width;
    final effectHeight = screen.height * 0.62;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(scale: value, child: child),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Center(
            child: SizedBox(
              width: effectWidth,
              height: effectHeight,
              child: ClipRect(
                child: _GiftEffectVisual(
                  slide: widget.slide,
                  ready: _ready,
                  failed: _failed,
                  controller: _controller,
                  isAnimatedImageGift: _isAnimatedImageGift,
                ),
              ),
            ),
          ),
          Positioned(
            top: safeTop + 92,
            left: 14,
            right: 14,
            child: Center(child: _GoldenGiftAnnouncementPill(slide: widget.slide)),
          ),
        ],
      ),
    );
  }
}

class _GiftEffectVisual extends StatelessWidget {
  const _GiftEffectVisual({
    required this.slide,
    required this.ready,
    required this.failed,
    required this.controller,
    required this.isAnimatedImageGift,
  });

  final GiftSlide slide;
  final bool ready;
  final bool failed;
  final VideoPlayerController? controller;
  final bool isAnimatedImageGift;

  @override
  Widget build(BuildContext context) {
    if (ready && isAnimatedImageGift) {
      return Image.asset(
        slide.videoAssetPath!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => _VideoGiftFallback(
          failed: true,
          colors: slide.colors,
          icon: slide.giftIcon,
        ),
      );
    }

    final videoController = controller;
    if (ready && videoController != null) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: videoController.value.size.width,
          height: videoController.value.size.height,
          child: VideoPlayer(videoController),
        ),
      );
    }

    return Center(
      child: SizedBox(
        width: 220,
        height: 220,
        child: _VideoGiftFallback(
          failed: failed,
          colors: slide.colors,
          icon: slide.giftIcon,
        ),
      ),
    );
  }
}

class _GoldenGiftAnnouncementPill extends StatelessWidget {
  const _GoldenGiftAnnouncementPill({required this.slide});

  final GiftSlide slide;

  @override
  Widget build(BuildContext context) {
    final receiver = slide.receiverName.trim();
    final giftName = slide.giftName.trim();
    final comboText = slide.combo > 1 ? '  x${slide.combo}' : '';
    final announcement = receiver.isEmpty || receiver.toLowerCase() == 'all'
        ? '${slide.senderName} sent $giftName to everyone$comboText'
        : '${slide.senderName} sent $giftName to $receiver$comboText';

    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.94),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF7C7),
            Color(0xFFFFD66B),
            Color(0xFFC88922),
            Color(0xFFFFE49A),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72), width: 1.35),
        boxShadow: [
          BoxShadow(
            color: RoomColors.gold.withValues(alpha: 0.58),
            blurRadius: 28,
            spreadRadius: 1.5,
            offset: const Offset(0, 9),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.30),
            blurRadius: 18,
            spreadRadius: 0.8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.58),
                      Colors.white.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.09),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -34,
              top: -26,
              child: Transform.rotate(
                angle: -0.44,
                child: Container(
                  width: 48,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.72),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFFBE3),
                        Color(0xFFFFCD3A),
                        Color(0xFFB36B0D),
                      ],
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.78), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    size: 15,
                    color: Color(0xFF4B2800),
                  ),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    announcement,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF4B2800),
                      fontSize: 14.6,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.05,
                      shadows: [
                        Shadow(color: Colors.white, blurRadius: 8),
                        Shadow(color: Color(0xFFFFF1B8), blurRadius: 15),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(color: colors.first.withValues(alpha: 0.30), blurRadius: 28),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 58),
            const SizedBox(height: 12),
            Text(
              failed ? 'Gift effect missing' : 'Loading effect...',
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
