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
    this.remoteUrl,
    this.thumbnailUrl,
  });

  final String id;
  final String name;
  final RoomWallpaperType type;
  final String assetPath;
  final String? remoteUrl;
  final String? thumbnailUrl;

  bool get isVideo => type == RoomWallpaperType.video;
  bool get isCdnReady => remoteUrl != null && remoteUrl!.trim().isNotEmpty;
}

const List<RoomWallpaperItem> ownedRoomWallpaperItems = [
  RoomWallpaperItem(
    id: 'celestial_falls',
    name: 'Celestial Falls',
    type: RoomWallpaperType.image,
    assetPath: '$roomDefaultBackgroundAssetBase/celestial_falls.webp',
  ),
  RoomWallpaperItem(
    id: 'moonlit_biolume_shore',
    name: 'Moonlit Biolume Shore',
    type: RoomWallpaperType.image,
    assetPath: '$roomDefaultBackgroundAssetBase/moonlit_biolume_shore.webp',
  ),
  RoomWallpaperItem(
    id: 'aurora_frost_lake',
    name: 'Aurora Frost Lake',
    type: RoomWallpaperType.image,
    assetPath: '$roomDefaultBackgroundAssetBase/aurora_frost_lake.webp',
  ),
  RoomWallpaperItem(
    id: 'desert_dusk_oasis',
    name: 'Desert Dusk Oasis',
    type: RoomWallpaperType.image,
    assetPath: '$roomDefaultBackgroundAssetBase/desert_dusk_oasis.webp',
  ),
  RoomWallpaperItem(
    id: 'alpine_twilight_mirror',
    name: 'Alpine Twilight Mirror',
    type: RoomWallpaperType.image,
    assetPath: '$roomDefaultBackgroundAssetBase/alpine_twilight_mirror.webp',
  ),
  RoomWallpaperItem(
    id: 'crimson_coast_beacon',
    name: 'Crimson Coast Beacon',
    type: RoomWallpaperType.image,
    assetPath: '$roomDefaultBackgroundAssetBase/crimson_coast_beacon.webp',
  ),
  RoomWallpaperItem(
    id: 'moonlit_whisper_grove',
    name: 'Moonlit Whisper Grove',
    type: RoomWallpaperType.image,
    assetPath: '$roomDefaultBackgroundAssetBase/moonlit_whisper_grove.webp',
  ),
  RoomWallpaperItem(
    id: 'cosmic_horizon_veil',
    name: 'Cosmic Horizon Veil',
    type: RoomWallpaperType.image,
    assetPath: '$roomDefaultBackgroundAssetBase/cosmic_horizon_veil.webp',
  ),
];
