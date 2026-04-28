import 'package:flutter/material.dart';

import 'room_theme.dart';

enum RoomAvatarFrameType { staticFrame, dynamicFrame }

class RoomAvatarFrame {
  const RoomAvatarFrame({
    required this.id,
    required this.name,
    required this.type,
    required this.accent,
    this.assetPath,
  });

  final String id;
  final String name;
  final RoomAvatarFrameType type;
  final Color accent;
  final String? assetPath;

  bool get isDynamic => type == RoomAvatarFrameType.dynamicFrame;
}

const RoomAvatarFrame defaultStaticAvatarFrame = RoomAvatarFrame(
  id: 'classic_gold_ring',
  name: 'Classic Gold Ring',
  type: RoomAvatarFrameType.staticFrame,
  accent: RoomColors.gold,
);

const RoomAvatarFrame defaultDynamicAvatarFrame = RoomAvatarFrame(
  id: 'aqua_pulse_ring',
  name: 'Aqua Pulse Ring',
  type: RoomAvatarFrameType.dynamicFrame,
  accent: RoomColors.aqua,
);

const List<RoomAvatarFrame> mockOwnedAvatarFrames = [
  defaultStaticAvatarFrame,
  defaultDynamicAvatarFrame,
];

class RoomAvatarFrameHost extends StatefulWidget {
  const RoomAvatarFrameHost({
    super.key,
    required this.child,
    required this.size,
    this.frame,
  });

  final Widget child;
  final double size;
  final RoomAvatarFrame? frame;

  @override
  State<RoomAvatarFrameHost> createState() => _RoomAvatarFrameHostState();
}

class _RoomAvatarFrameHostState extends State<RoomAvatarFrameHost> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    if (widget.frame?.isDynamic ?? false) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant RoomAvatarFrameHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isDynamic = widget.frame?.isDynamic ?? false;
    if (isDynamic && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!isDynamic && _controller.isAnimating) {
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
    final frame = widget.frame;
    if (frame == null) return widget.child;

    return SizedBox(
      width: widget.size + 8,
      height: widget.size + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (frame.assetPath != null)
            Image.asset(
              frame.assetPath!,
              width: widget.size + 8,
              height: widget.size + 8,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _GeneratedFrame(frame: frame, size: widget.size + 8, controller: _controller),
            )
          else
            _GeneratedFrame(frame: frame, size: widget.size + 8, controller: _controller),
          widget.child,
        ],
      ),
    );
  }
}

class _GeneratedFrame extends StatelessWidget {
  const _GeneratedFrame({required this.frame, required this.size, required this.controller});

  final RoomAvatarFrame frame;
  final double size;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    if (!frame.isDynamic) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: frame.accent.withValues(alpha: 0.72), width: 2.2),
          boxShadow: [BoxShadow(color: frame.accent.withValues(alpha: 0.18), blurRadius: 12)],
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: controller.value * 6.28318,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  frame.accent.withValues(alpha: 0.10),
                  frame.accent.withValues(alpha: 0.88),
                  RoomColors.violet.withValues(alpha: 0.55),
                  frame.accent.withValues(alpha: 0.10),
                ],
              ),
              boxShadow: [BoxShadow(color: frame.accent.withValues(alpha: 0.22), blurRadius: 16)],
            ),
          ),
        );
      },
    );
  }
}

enum RoomWallpaperType { image, video }

class RoomWallpaperItem {
  const RoomWallpaperItem({
    required this.id,
    required this.name,
    required this.type,
    required this.assetPath,
  });

  final String id;
  final String name;
  final RoomWallpaperType type;
  final String assetPath;

  bool get isVideo => type == RoomWallpaperType.video;
}

const List<RoomWallpaperItem> ownedRoomWallpaperItems = [
  RoomWallpaperItem(
    id: 'default_luxury_static',
    name: 'Default Luxury',
    type: RoomWallpaperType.image,
    assetPath: 'assets/images/rooms/backgrounds/default_luxury.png',
  ),
  RoomWallpaperItem(
    id: 'default_dark_static',
    name: 'Default Dark',
    type: RoomWallpaperType.image,
    assetPath: 'assets/images/rooms/backgrounds/default_dark.png',
  ),
  RoomWallpaperItem(
    id: 'vibe_sync_static',
    name: 'VibeSync',
    type: RoomWallpaperType.image,
    assetPath: 'assets/images/rooms/backgrounds/vibe_sync.png',
  ),
];
