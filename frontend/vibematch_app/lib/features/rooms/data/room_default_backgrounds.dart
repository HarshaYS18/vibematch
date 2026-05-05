/// Built-in fallback/default chatroom backgrounds for VibeMatch.
///
/// These 8 are the only default local chatroom backgrounds we want visible.
/// Future backend/CDN backgrounds should use the same `id` values when seeding
/// the server-side theme registry.
class RoomDefaultBackground {
  const RoomDefaultBackground({
    required this.id,
    required this.name,
    required this.assetPath,
  });

  final String id;
  final String name;
  final String assetPath;
}

abstract final class RoomDefaultBackgrounds {
  static const String assetBasePath =
      'assets/images/room_backgrounds/chat_room/default';

  static const List<RoomDefaultBackground> all = [
    RoomDefaultBackground(
      id: 'celestial_falls',
      name: 'Celestial Falls',
      assetPath: '$assetBasePath/celestial_falls.webp',
    ),
    RoomDefaultBackground(
      id: 'moonlit_biolume_shore',
      name: 'Moonlit Biolume Shore',
      assetPath: '$assetBasePath/moonlit_biolume_shore.webp',
    ),
    RoomDefaultBackground(
      id: 'aurora_frost_lake',
      name: 'Aurora Frost Lake',
      assetPath: '$assetBasePath/aurora_frost_lake.webp',
    ),
    RoomDefaultBackground(
      id: 'desert_dusk_oasis',
      name: 'Desert Dusk Oasis',
      assetPath: '$assetBasePath/desert_dusk_oasis.webp',
    ),
    RoomDefaultBackground(
      id: 'alpine_twilight_mirror',
      name: 'Alpine Twilight Mirror',
      assetPath: '$assetBasePath/alpine_twilight_mirror.webp',
    ),
    RoomDefaultBackground(
      id: 'crimson_coast_beacon',
      name: 'Crimson Coast Beacon',
      assetPath: '$assetBasePath/crimson_coast_beacon.webp',
    ),
    RoomDefaultBackground(
      id: 'moonlit_whisper_grove',
      name: 'Moonlit Whisper Grove',
      assetPath: '$assetBasePath/moonlit_whisper_grove.webp',
    ),
    RoomDefaultBackground(
      id: 'cosmic_horizon_veil',
      name: 'Cosmic Horizon Veil',
      assetPath: '$assetBasePath/cosmic_horizon_veil.webp',
    ),
  ];

  static const RoomDefaultBackground fallback = all[0];

  static RoomDefaultBackground byId(String? id) {
    if (id == null || id.trim().isEmpty) return fallback;

    for (final background in all) {
      if (background.id == id) return background;
    }

    return fallback;
  }
}
