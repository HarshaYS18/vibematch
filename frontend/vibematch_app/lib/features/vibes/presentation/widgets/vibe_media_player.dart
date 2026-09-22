import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/network/vm_api_config.dart';
import '../../models/vibe_models.dart';
import 'vibe_media_playback_gate.dart';

class VibeMediaPlayer extends StatelessWidget {
  const VibeMediaPlayer({
    super.key,
    required this.vibe,
    required this.onDoubleTap,
    this.respectFeedPause = true,
    this.autoplay = false,
    this.playbackGate,
  });

  final VibeItem vibe;
  final VoidCallback onDoubleTap;
  final bool respectFeedPause;
  final bool autoplay;
  final VibeMediaPlaybackGate? playbackGate;

  @override
  Widget build(BuildContext context) {
    final mediaUrl = _resolvedMediaUrl(vibe.mediaUrl);
    if (vibe.mediaType == VibeMediaType.text) return const SizedBox.shrink();
    if (mediaUrl == null) {
      return GestureDetector(
        onDoubleTap: onDoubleTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: vibe.colors),
          ),
          child: Icon(
            vibe.mediaType == VibeMediaType.video
                ? Icons.play_circle_fill_rounded
                : Icons.photo_rounded,
            color: Colors.white,
            size: 72,
          ),
        ),
      );
    }
    if (vibe.mediaType == VibeMediaType.video) {
      final resolvedVideoKey = vibe.id.trim().isNotEmpty
          ? vibe.id.trim()
          : mediaUrl.hashCode.toString();
      return GestureDetector(
        onDoubleTap: onDoubleTap,
        child: _NetworkVideoPlayer(
          key: ValueKey('vibe_video_$resolvedVideoKey'),
          videoKey: resolvedVideoKey,
          url: mediaUrl,
          respectFeedPause: respectFeedPause,
          autoplay: autoplay,
          playbackGate: playbackGate,
        ),
      );
    }
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Image.network(
        mediaUrl,
        cacheWidth: (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round(),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) =>
            loadingProgress == null
            ? child
            : _MediaLoading(colors: vibe.colors),
        errorBuilder: (_, _, _) => _MediaFallback(vibe: vibe),
      ),
    );
  }
}

class _NetworkVideoPlayer extends StatefulWidget {
  const _NetworkVideoPlayer({
    required this.videoKey,
    required this.url,
    required this.respectFeedPause,
    required this.autoplay,
    required this.playbackGate,
    super.key,
  });

  final String videoKey;
  final String url;
  final bool respectFeedPause;
  final bool autoplay;
  final VibeMediaPlaybackGate? playbackGate;

  @override
  State<_NetworkVideoPlayer> createState() => _NetworkVideoPlayerState();
}

class _NetworkVideoPlayerState extends State<_NetworkVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isReady = false;
  bool _hasError = false;
  bool _showPlayButton = true;
  bool _manualPlayRequested = false;

  @override
  void initState() {
    super.initState();
    final gate = widget.playbackGate;
    assert(!widget.respectFeedPause || gate != null);
    if (widget.respectFeedPause && gate != null) {
      gate.feedPlaybackPaused.addListener(_handlePlaybackGateChanged);
      gate.feedScrollTick.addListener(_handleScrollTick);
      gate.activeFeedVideoKey.addListener(_handleActiveVideoChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncAutoplayWithVisibility(),
    );
  }

  @override
  void didUpdateWidget(covariant _NetworkVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.videoKey != widget.videoKey) {
      oldWidget.playbackGate?.releaseActiveFeedVideo(oldWidget.videoKey);
      _controller?.dispose();
      _controller = null;
      _isReady = false;
      _hasError = false;
      _showPlayButton = true;
      _manualPlayRequested = false;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _syncAutoplayWithVisibility(),
      );
    }
  }

  @override
  void dispose() {
    widget.playbackGate?.releaseActiveFeedVideo(widget.videoKey);
    if (widget.respectFeedPause) {
      final gate = widget.playbackGate;
      gate?.feedPlaybackPaused.removeListener(_handlePlaybackGateChanged);
      gate?.feedScrollTick.removeListener(_handleScrollTick);
      gate?.activeFeedVideoKey.removeListener(_handleActiveVideoChanged);
    }
    _controller?.dispose();
    super.dispose();
  }

  void _initializeController({bool playAfterReady = false}) {
    if (_controller != null) return;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..initialize()
          .then((_) {
            if (!mounted) return;
            setState(() => _isReady = true);
            if (playAfterReady) _manualPlayRequested = true;
            _syncAutoplayWithVisibility();
          })
          .catchError((_) {
            if (mounted) setState(() => _hasError = true);
          });
  }

  void _handlePlaybackGateChanged() {
    if (widget.playbackGate?.feedPlaybackPaused.value == true) {
      _pauseForVisibility(resetManualPlay: false);
      return;
    }
    _syncAutoplayWithVisibility();
  }

  void _handleScrollTick() {
    _syncAutoplayWithVisibility();
    if (!_isNearViewport() && !_manualPlayRequested) {
      _disposeControllerForDistance();
    }
  }

  void _handleActiveVideoChanged() {
    if (widget.playbackGate?.activeFeedVideoKey.value != widget.videoKey) {
      _pauseForVisibility(resetManualPlay: false);
      if (!_isNearViewport()) _disposeControllerForDistance();
    }
  }

  bool _shouldAutoplayNow() {
    if (widget.autoplay) return true;
    if (!widget.respectFeedPause) return false;
    if (widget.playbackGate?.feedPlaybackPaused.value == true) return false;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final height = renderObject.size.height;
    if (height <= 0) return false;
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return false;
    final viewportTop = mediaQuery.padding.top;
    final viewportBottom =
        mediaQuery.size.height - mediaQuery.padding.bottom - 92;
    final visibleTop = topLeft.dy.clamp(viewportTop, viewportBottom);
    final visibleBottom = (topLeft.dy + height).clamp(
      viewportTop,
      viewportBottom,
    );
    final visibleHeight = visibleBottom - visibleTop;
    if (visibleHeight <= 0) return false;
    final visibleRatio = visibleHeight / height;
    final itemCenter = topLeft.dy + height / 2;
    final viewportCenter = (viewportTop + viewportBottom) / 2;
    final distanceFromCenter = (itemCenter - viewportCenter).abs();
    return visibleRatio >= 0.58 && distanceFromCenter < height * 0.72;
  }

  void _syncAutoplayWithVisibility() {
    if (!mounted) return;
    final shouldPlay = _manualPlayRequested || _shouldAutoplayNow();
    if (shouldPlay && _controller == null) {
      _initializeController(playAfterReady: _manualPlayRequested);
      return;
    }
    final controller = _controller;
    if (controller == null || !_isReady) return;
    if (shouldPlay && widget.playbackGate?.feedPlaybackPaused.value != true) {
      widget.playbackGate?.claimActiveFeedVideo(widget.videoKey);
      if (!controller.value.isPlaying) controller.play();
      if (_showPlayButton) setState(() => _showPlayButton = false);
    } else {
      _pauseForVisibility(resetManualPlay: false);
    }
  }

  bool _isNearViewport() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return false;
    final top = renderObject.localToGlobal(Offset.zero).dy;
    final bottom = top + renderObject.size.height;
    final viewportTop = -renderObject.size.height * 0.6;
    final viewportBottom =
        mediaQuery.size.height + renderObject.size.height * 0.6;
    return bottom >= viewportTop && top <= viewportBottom;
  }

  void _disposeControllerForDistance() {
    final controller = _controller;
    if (controller == null) return;
    _controller = null;
    _isReady = false;
    _showPlayButton = true;
    controller.dispose();
    if (mounted) setState(() {});
  }

  void _pauseForVisibility({required bool resetManualPlay}) {
    final controller = _controller;
    if (controller == null || !_isReady) return;
    if (resetManualPlay) _manualPlayRequested = false;
    if (controller.value.isPlaying) controller.pause();
    if (!_showPlayButton && mounted) setState(() => _showPlayButton = true);
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null) {
      _manualPlayRequested = true;
      _initializeController(playAfterReady: true);
      return;
    }
    if (!_isReady) return;
    if (controller.value.isPlaying) {
      _manualPlayRequested = false;
      widget.playbackGate?.releaseActiveFeedVideo(widget.videoKey);
      controller.pause();
      setState(() => _showPlayButton = true);
    } else {
      _manualPlayRequested = true;
      widget.playbackGate?.claimActiveFeedVideo(widget.videoKey);
      controller.play();
      setState(() => _showPlayButton = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_hasError)
      return const Center(
        child: Icon(
          Icons.broken_image_rounded,
          size: 44,
          color: Color(0xFF8C8198),
        ),
      );
    if (controller == null) {
      return Material(
        color: Colors.black,
        child: InkWell(
          onTap: _togglePlayback,
          child: const Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 58,
            ),
          ),
        ),
      );
    }
    if (!_isReady) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF111015),
          strokeWidth: 2.6,
        ),
      );
    }
    final videoSize = controller.value.size;
    final videoWidth = videoSize.width <= 0 ? 9.0 : videoSize.width;
    final videoHeight = videoSize.height <= 0 ? 16.0 : videoSize.height;
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Container(color: Colors.black),
        FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: videoWidth,
            height: videoHeight,
            child: VideoPlayer(controller),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _togglePlayback,
            child: Center(
              child: AnimatedOpacity(
                opacity: _showPlayButton ? 1 : 0,
                duration: const Duration(milliseconds: 140),
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.34),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaLoading extends StatelessWidget {
  const _MediaLoading({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6),
      ),
    );
  }
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback({required this.vibe});

  final VibeItem vibe;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: vibe.colors)),
      child: Center(
        child: Icon(
          vibe.mediaType == VibeMediaType.video
              ? Icons.play_circle_fill_rounded
              : Icons.photo_rounded,
          color: Colors.white,
          size: 72,
        ),
      ),
    );
  }
}

String? _resolvedMediaUrl(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return VmApiConfig.mediaUrl(trimmed);
}
