import 'package:flutter/material.dart';

import 'room_theme.dart';

const RoomBackgroundTheme cricketFloodlightArenaBackgroundTheme = RoomBackgroundTheme(
  id: 'cricket_floodlight_arena',
  name: 'Floodlight Arena',
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
  return cricketRoomBackgroundThemes.any((item) => item.id == theme.id) || theme.id.startsWith('cricket_');
}


class CricketRoomBackgroundPickerSheet extends StatelessWidget {
  const CricketRoomBackgroundPickerSheet({
    super.key,
    required this.currentTheme,
    required this.onThemeSelected,
  });

  final RoomBackgroundTheme currentTheme;
  final ValueChanged<RoomBackgroundTheme> onThemeSelected;

  @override
  Widget build(BuildContext context) {
    return RoomBackgroundPickerSheet(
      currentTheme: currentTheme,
      onThemeSelected: onThemeSelected,
      onStoreTap: () {
        RoomToast.show(
          context,
          'Cricket backgrounds will update from CDN',
        );
      },
      viewerState: const RoomBackgroundViewerState(
        ownedThemeIds: {
          'cricket_floodlight_arena',
          'cricket_stadium_night',
          'cricket_royal_pitch',
        },
      ),
    );
  }
}
