import 'package:flutter/material.dart';

import '../../../../core/widgets/vm_avatar_frame.dart';
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

  VmAvatarFrameStyle toVmFrameStyle() {
    return VmAvatarFrameStyle(
      id: id,
      name: name,
      accent: accent,
      assetPath: assetPath,
      isDynamic: isDynamic,
    );
  }
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

class RoomAvatarFrameHost extends StatelessWidget {
  const RoomAvatarFrameHost({
    super.key,
    required this.child,
    required this.size,
    this.frame,
    this.framePadding = 8,
    this.staticStrokeWidth = 2.2,
  });

  final Widget child;
  final double size;
  final RoomAvatarFrame? frame;
  final double framePadding;
  final double staticStrokeWidth;

  @override
  Widget build(BuildContext context) {
    return VmAvatarFrameHost(
      size: size,
      frame: frame?.toVmFrameStyle(),
      framePadding: framePadding,
      staticStrokeWidth: staticStrokeWidth,
      child: child,
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
