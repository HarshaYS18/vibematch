import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../presentation/live_room_models.dart';

class CleanVideoGiftOverlay extends StatelessWidget {
  const CleanVideoGiftOverlay({
    super.key,
    required this.slides,
    required this.onVideoFinished,
  });

  final List<GiftSlide> slides;
  final ValueChanged<GiftSlide> onVideoFinished;

  @override
  Widget build(BuildContext context) {
    final activeSlide = slides.where((slide) => slide.isVideoGift).firstOrNull;
    if (activeSlide == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: _CleanVideoGiftCard(
          key: ValueKey(activeSlide.id),
          slide: activeSlide,
          onVideoFinished: onVideoFinished,
        ),
      ),
    );
  }
}

class _CleanVideoGiftCard extends StatefulWidget {
  const _CleanVideoGiftCard({
    super.key,
    required this.slide,
    required this.onVideoFinished,
  });

  final GiftSlide slide;
  final ValueChanged<GiftSlide> onVideoFinished;

  @override
  State<_CleanVideoGiftCard> createState() => _CleanVideoGiftCardState();
}

class _CleanVideoGiftCardState extends State<_CleanVideoGiftCard> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final networkUrl = widget.slide.videoUrl?.trim();
    final localPath = widget.slide.videoAssetPath?.trim();
    if ((networkUrl == null || networkUrl.isEmpty) &&
        (localPath == null || localPath.isEmpty)) {
      return;
    }
    try {
      final controller = networkUrl != null && networkUrl.isNotEmpty
          ? VideoPlayerController.networkUrl(Uri.parse(networkUrl))
          : VideoPlayerController.asset(localPath!);
      _controller = controller;
      controller.addListener(_onTick);
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(1.0);
      await controller.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      _finish();
    }
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    if (duration == Duration.zero) return;
    if (controller.value.position >= duration - const Duration(milliseconds: 120)) {
      _finish();
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onVideoFinished(widget.slide);
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onTick);
      controller.pause();
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
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
      child: Transform.translate(
        offset: Offset(0, screen.height * 0.12),
        child: Center(
          child: SizedBox(
            width: screen.width,
            height: screen.height * 0.62,
            child: ClipRect(
              child: _ready && _controller != null
                  ? FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    )
                  : _GiftFallback(
                      assetUrl: widget.slide.giftAssetUrl,
                      assetPath: widget.slide.giftAssetPath,
                      colors: widget.slide.colors,
                      icon: widget.slide.giftIcon,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GiftFallback extends StatelessWidget {
  const _GiftFallback({
    required this.assetUrl,
    required this.assetPath,
    required this.colors,
    required this.icon,
  });

  final String? assetUrl;
  final String? assetPath;
  final List<Color> colors;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final networkUrl = assetUrl?.trim();
    if (networkUrl != null && networkUrl.isNotEmpty) {
      return Image.network(
        networkUrl,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _LocalOrIconFallback(
          assetPath: assetPath,
          colors: colors,
          icon: icon,
        ),
      );
    }
    return _LocalOrIconFallback(assetPath: assetPath, colors: colors, icon: icon);
  }
}

class _LocalOrIconFallback extends StatelessWidget {
  const _LocalOrIconFallback({
    required this.assetPath,
    required this.colors,
    required this.icon,
  });

  final String? assetPath;
  final List<Color> colors;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final path = assetPath?.toLowerCase().trim() ?? '';
    if (path.endsWith('.webp') ||
        path.endsWith('.gif') ||
        path.endsWith('.png') ||
        path.endsWith('.apng')) {
      return Image.asset(assetPath!, fit: BoxFit.cover, gaplessPlayback: true);
    }
    return Center(
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(colors: colors),
        ),
        child: Icon(icon, color: Colors.white, size: 58),
      ),
    );
  }
}
