import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/public_profile_models.dart';
import 'public_profile_shared_widgets.dart';

class PublicVibeCard extends StatelessWidget {
  const PublicVibeCard({
    super.key,
    required this.vibe,
    required this.onTap,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
  });

  final PublicVibeItem vibe;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: publicProfileWhitePanelDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: vibe.colors),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(vibe.icon, color: Colors.white),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vibe.title,
                          style: const TextStyle(
                            color: Color(0xFF251538),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${vibe.mediaType} · ${vibe.timeAgo}',
                          style: const TextStyle(
                            color: Color(0xFF8C7B8F),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              _PublicVibeMediaPreview(vibe: vibe),
              const SizedBox(height: 13),
              Text(
                vibe.body,
                style: const TextStyle(
                  color: Color(0xFF5E5363),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _VibeActionButton(
                    icon: Icons.favorite_rounded,
                    label: vibe.likes,
                    color: const Color(0xFFE84C72),
                    onTap: onLikeTap,
                  ),
                  const SizedBox(width: 9),
                  _VibeActionButton(
                    icon: Icons.mode_comment_rounded,
                    label: vibe.comments,
                    color: const Color(0xFF6D5DF6),
                    onTap: onCommentTap,
                  ),
                  const Spacer(),
                  _VibeActionButton(
                    icon: Icons.ios_share_rounded,
                    label: 'Share',
                    color: const Color(0xFF12C7B7),
                    onTap: onShareTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicVibeMediaPreview extends StatelessWidget {
  const _PublicVibeMediaPreview({required this.vibe});

  final PublicVibeItem vibe;

  @override
  Widget build(BuildContext context) {
    final mediaUrl = vibe.mediaUrl?.trim();
    final type = vibe.mediaType.toLowerCase().trim();

    if (mediaUrl != null && mediaUrl.isNotEmpty && type == 'photo') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Image.network(
            mediaUrl,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => _FallbackMedia(vibe: vibe),
          ),
        ),
      );
    }

    if (mediaUrl != null && mediaUrl.isNotEmpty && type == 'video') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: _AutoPlayPublicVibeVideo(url: mediaUrl, fallback: _FallbackMedia(vibe: vibe)),
        ),
      );
    }

    return _FallbackMedia(vibe: vibe);
  }
}

class _AutoPlayPublicVibeVideo extends StatefulWidget {
  const _AutoPlayPublicVibeVideo({required this.url, required this.fallback});

  final String url;
  final Widget fallback;

  @override
  State<_AutoPlayPublicVibeVideo> createState() => _AutoPlayPublicVibeVideoState();
}

class _AutoPlayPublicVibeVideoState extends State<_AutoPlayPublicVibeVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant _AutoPlayPublicVibeVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller?.dispose();
      _controller = null;
      _ready = false;
      _init();
    }
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _ready = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_ready || controller == null || !controller.value.isInitialized) return widget.fallback;
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        const Positioned(
          right: 12,
          bottom: 12,
          child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
        ),
      ],
    );
  }
}

class _FallbackMedia extends StatelessWidget {
  const _FallbackMedia({required this.vibe});

  final PublicVibeItem vibe;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: vibe.colors,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: PublicCoverPatternPainter())),
          Center(
            child: Icon(
              vibe.icon,
              color: Colors.white.withValues(alpha: 0.86),
              size: 46,
            ),
          ),
        ],
      ),
    );
  }
}

class PublicCoverPatternPainter extends CustomPainter {
  const PublicCoverPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final softPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.22), 42, softPaint);
    canvas.drawCircle(Offset(size.width * 0.86, size.height * 0.78), 58, softPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.55, -18, 110, 72),
        const Radius.circular(28),
      ),
      softPaint,
    );

    for (var i = 0; i < 5; i++) {
      final y = 18.0 + (i * 27.0);
      canvas.drawLine(Offset(18, y), Offset(size.width - 18, y + 22), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VibeActionButton extends StatelessWidget {
  const _VibeActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: Color(0xFF251538), fontSize: 11, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
