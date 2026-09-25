import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../../foundation/runtime/media_resource_lifecycle.dart';
import '../../../presentation/live_room_models.dart';
import '../runtime/gift_video_resource_participant.dart';
import '../../../presentation/widgets/gift_modules/gift_panel_constants.dart';

class CleanVideoGiftOverlay extends StatelessWidget {
  const CleanVideoGiftOverlay({
    super.key,
    required this.roomPublicId,
    required this.slides,
    required this.onVideoFinished,
  });

  final String roomPublicId;
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
          roomPublicId: roomPublicId,
          slide: activeSlide,
          onVideoFinished: onVideoFinished,
        ),
      ),
    );
  }
}

class _CleanVideoGiftCard extends ConsumerStatefulWidget {
  const _CleanVideoGiftCard({
    super.key,
    required this.roomPublicId,
    required this.slide,
    required this.onVideoFinished,
  });

  final String roomPublicId;
  final GiftSlide slide;
  final ValueChanged<GiftSlide> onVideoFinished;

  @override
  ConsumerState<_CleanVideoGiftCard> createState() =>
      _CleanVideoGiftCardState();
}

class _CleanVideoGiftCardState extends ConsumerState<_CleanVideoGiftCard> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _finished = false;
  bool _controllerDisposed = false;
  MediaResourceRegistry? _resourceRegistry;
  GiftVideoResourceParticipant? _resourceParticipant;

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
      if (!mounted) {
        await _disposeController();
        return;
      }
      setState(() => _ready = true);
      await _attachResource();
    } catch (_) {
      await _disposeController();
      if (mounted) _finish();
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

  Future<void> _attachResource() async {
    if (!mounted || _resourceParticipant != null) return;
    final registry = ref.read(mediaResourceRegistryProvider);
    if (registry == null) return;

    final participant = GiftVideoResourceParticipant(
      resourceId: 'gift-video:${widget.roomPublicId}:${widget.slide.id}',
      pause: _pauseForLifecycle,
      resume: _resumeForLifecycle,
      releaseResource: _releaseForLifecycle,
    );
    try {
      if (!registry.register(participant)) return;
      _resourceRegistry = registry;
      _resourceParticipant = participant;
      await participant.onForegroundChanged(registry.isForeground);
    } catch (_) {
      registry.unregister(
        participant.resourceId,
        expectedParticipant: participant,
      );
    }
  }

  Future<bool> _pauseForLifecycle() async {
    final controller = _controller;
    if (_controllerDisposed ||
        controller == null ||
        !controller.value.isInitialized) {
      return false;
    }
    final wasPlaying = controller.value.isPlaying;
    if (wasPlaying) await controller.pause();
    return wasPlaying;
  }

  Future<void> _resumeForLifecycle() async {
    final controller = _controller;
    if (_finished ||
        _controllerDisposed ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }
    await controller.play();
  }

  Future<void> _releaseForLifecycle() async {
    await _disposeController();
    _finish();
  }

  void _detachResource() {
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

  Future<void> _disposeController() async {
    if (_controllerDisposed) return;
    _controllerDisposed = true;
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    controller.removeListener(_onTick);
    try {
      await controller.pause();
    } catch (_) {}
    await controller.dispose();
  }

  @override
  void dispose() {
    _detachResource();
    unawaited(_disposeController());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final displayMode = GiftPanelConstants.displayModeForGiftName(widget.slide.giftName);
    final isLarge80 = displayMode == 'large_80';
    final boxWidth = isLarge80 ? screen.width * 0.96 : screen.width;
    final boxHeight = isLarge80 ? screen.height * 0.80 : screen.height * 0.62;
    final offsetY = isLarge80 ? 0.0 : screen.height * 0.12;
    final fit = isLarge80 ? BoxFit.contain : BoxFit.cover;

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
        offset: Offset(0, offsetY),
        child: Center(
          child: SizedBox(
            width: boxWidth,
            height: boxHeight,
            child: ClipRect(
              child: _ready && _controller != null
                  ? FittedBox(
                      fit: fit,
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
                      fit: fit,
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
    required this.fit,
  });

  final String? assetUrl;
  final String? assetPath;
  final List<Color> colors;
  final IconData icon;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final networkUrl = assetUrl?.trim();
    if (networkUrl != null && networkUrl.isNotEmpty) {
      return Image.network(
        networkUrl,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _LocalOrIconFallback(
          assetPath: assetPath,
          colors: colors,
          icon: icon,
          fit: fit,
        ),
      );
    }
    return _LocalOrIconFallback(
      assetPath: assetPath,
      colors: colors,
      icon: icon,
      fit: fit,
    );
  }
}

class _LocalOrIconFallback extends StatelessWidget {
  const _LocalOrIconFallback({
    required this.assetPath,
    required this.colors,
    required this.icon,
    required this.fit,
  });

  final String? assetPath;
  final List<Color> colors;
  final IconData icon;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final path = assetPath?.toLowerCase().trim() ?? '';
    if (path.endsWith('.webp') ||
        path.endsWith('.gif') ||
        path.endsWith('.png') ||
        path.endsWith('.apng')) {
      return Image.asset(assetPath!, fit: fit, gaplessPlayback: true);
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
