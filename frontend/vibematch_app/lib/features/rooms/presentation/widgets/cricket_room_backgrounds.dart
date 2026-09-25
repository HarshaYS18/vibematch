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
      theme.id.startsWith('cricket_');
}

/// Picks a Cricket Mode theme for the owning room.
///
/// Selection is emitted to the room-scoped callback; this widget never mutates
/// a process-global active background projection.
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
      // Keep bundled cricket backgrounds available when backend is offline.
    }
    return cricketRoomBackgroundThemes;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RoomBackgroundTheme>>(
      future: _backgroundsFuture,
      builder: (context, snapshot) {
        final themes = snapshot.data ?? cricketRoomBackgroundThemes;
        return Container(
          height: MediaQuery.sizeOf(context).height * 0.66,
          padding: EdgeInsets.fromLTRB(
            14,
            10,
            14,
            MediaQuery.paddingOf(context).bottom + 14,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(width: 44),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cricket Backgrounds',
                          style: TextStyle(
                            color: RoomColors.plum,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Cricket-only themes • backend/CDN update ready',
                          style: TextStyle(
                            color: Color(0xFF82758E),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Cricket Mode Backgrounds',
                style: TextStyle(
                  color: RoomColors.plum,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(),
                  itemCount: themes.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.18,
                  ),
                  itemBuilder: (context, index) {
                    final theme = themes[index];
                    final selected = theme.id == widget.currentTheme.id;
                    return _CricketBackgroundTile(
                      theme: theme,
                      selected: selected,
                      onTap: () {
                        widget.onThemeSelected(theme);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CricketBackgroundTile extends StatelessWidget {
  const _CricketBackgroundTile({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final RoomBackgroundTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: RoomColors.pearl,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? theme.accent : RoomColors.softLine,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _CricketBackgroundPreview(theme: theme),
                      Container(color: Colors.black.withValues(alpha: 0.12)),
                      if (selected)
                        const Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                theme.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RoomColors.plum,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Available',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF6E5B7A),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CricketBackgroundPreview extends StatelessWidget {
  const _CricketBackgroundPreview({required this.theme});

  final RoomBackgroundTheme theme;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: theme.fallbackColors.length >= 2
                  ? theme.fallbackColors
                  : const [Color(0xFF04130A), Color(0xFF0B3E1F)],
            ),
          ),
        ),
        if (theme.hasThumbnail || theme.isNetworkBacked)
          Image.network(
            theme.thumbnailUrl ?? theme.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _assetPreview();
            },
          )
        else
          _assetPreview(),
      ],
    );
  }

  Widget _assetPreview() {
    if (!theme.isAssetBacked) return const SizedBox.shrink();
    return Image.asset(
      theme.assetPath!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const SizedBox.shrink();
      },
    );
  }
}
