import 'package:flutter/material.dart';

import '../../data/room_background_config_repository.dart';
import 'room_theme.dart';

const RoomBackgroundTheme cricketFloodlightArenaBackgroundTheme = RoomBackgroundTheme(
  id: 'cricket_floodlight_arena',
  name: 'Floodlight Arena',
  assetPath: 'assets/images/room_backgrounds/cricket/default/floodlight_arena.webp',
  accent: Color(0xFF65FF8F),
  sourceType: RoomBackgroundSourceType.event,
  unlockType: RoomBackgroundUnlockType.free,
  ownershipType: RoomBackgroundOwnershipType.free,
  isDefault: true,
  overlayOpacity: 0.48,
  fallbackColors: [Color(0xFF04130A), Color(0xFF0B3E1F)],
);

const RoomBackgroundTheme cricketStadiumNightBackgroundTheme = RoomBackgroundTheme(
  id: 'cricket_stadium_night',
  name: 'Stadium Night',
  assetPath: 'assets/images/room_backgrounds/cricket/default/stadium_night.webp',
  accent: Color(0xFFFFD36A),
  sourceType: RoomBackgroundSourceType.event,
  unlockType: RoomBackgroundUnlockType.free,
  ownershipType: RoomBackgroundOwnershipType.free,
  overlayOpacity: 0.50,
  fallbackColors: [Color(0xFF07160D), Color(0xFF254B1D)],
);

const RoomBackgroundTheme cricketRoyalPitchBackgroundTheme = RoomBackgroundTheme(
  id: 'cricket_royal_pitch',
  name: 'Royal Pitch',
  assetPath: 'assets/images/room_backgrounds/cricket/default/royal_pitch.webp',
  accent: Color(0xFF12C7B7),
  sourceType: RoomBackgroundSourceType.event,
  unlockType: RoomBackgroundUnlockType.free,
  ownershipType: RoomBackgroundOwnershipType.free,
  overlayOpacity: 0.46,
  fallbackColors: [Color(0xFF051B13), Color(0xFF0C6040)],
);

const List<RoomBackgroundTheme> cricketRoomBackgroundThemes = [
  cricketFloodlightArenaBackgroundTheme,
  cricketStadiumNightBackgroundTheme,
  cricketRoyalPitchBackgroundTheme,
];

bool isCricketRoomBackground(RoomBackgroundTheme theme) {
  return cricketRoomBackgroundThemes.any((item) => item.id == theme.id) ||
      theme.id.startsWith('cricket_') ||
      theme.sourceType == RoomBackgroundSourceType.event;
}

class CricketRoomBackgroundPickerSheet extends StatefulWidget {
  const CricketRoomBackgroundPickerSheet({
    super.key,
    required this.currentTheme,
    required this.onThemeSelected,
    this.repository = const RoomBackgroundConfigRepository(),
  });

  final RoomBackgroundTheme currentTheme;
  final ValueChanged<RoomBackgroundTheme> onThemeSelected;
  final RoomBackgroundConfigRepository repository;

  @override
  State<CricketRoomBackgroundPickerSheet> createState() =>
      _CricketRoomBackgroundPickerSheetState();
}

class _CricketRoomBackgroundPickerSheetState
    extends State<CricketRoomBackgroundPickerSheet> {
  late final Future<List<RoomBackgroundTheme>> _backgroundsFuture;

  @override
  void initState() {
    super.initState();
    _backgroundsFuture = _loadBackgrounds();
  }

  Future<List<RoomBackgroundTheme>> _loadBackgrounds() async {
    try {
      final remoteThemes = await widget.repository.fetchBackgrounds(
        mode: 'cricket',
      );
      if (remoteThemes.isNotEmpty) return remoteThemes;
    } catch (_) {
      // Local bundled cricket backgrounds keep Cricket Mode working offline
      // during development or when backend config is temporarily unavailable.
    }
    return cricketRoomBackgroundThemes;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RoomBackgroundTheme>>(
      future: _backgroundsFuture,
      builder: (context, snapshot) {
        final themes = snapshot.data ?? cricketRoomBackgroundThemes;
        final viewerState = RoomBackgroundViewerState(
          ownedThemeIds: themes.map((theme) => theme.id).toSet(),
        );

        return RoomBackgroundPickerSheet(
          currentTheme: widget.currentTheme,
          onThemeSelected: widget.onThemeSelected,
          onStoreTap: () {
            RoomToast.show(
              context,
              snapshot.connectionState == ConnectionState.waiting
                  ? 'Loading cricket backgrounds...'
                  : 'Cricket backgrounds update from backend/CDN config',
            );
          },
          viewerState: viewerState,
          overrideThemes: themes,
          title: 'Cricket Backgrounds',
          subtitle: 'Cricket-only themes • backend/CDN update ready',
          sectionTitle: 'Cricket Mode Backgrounds',
        );
      },
    );
  }
}
