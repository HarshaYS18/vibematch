import 'package:flutter/material.dart';

class RoomColors {
  static const deep = Color(0xFF070414);
  static const plum = Color(0xFF251538);
  static const violet = Color(0xFF7A5CFF);
  static const aqua = Color(0xFF12C7B7);
  static const coral = Color(0xFFE84C72);
  static const gold = Color(0xFFFFC857);
  static const pearl = Color(0xFFFAF7F1);
  static const line = Color(0x22FFFFFF);
  static const softLine = Color(0xFFEDE3D7);
  static const adminMute = Color(0xFFFF7A45);
  static const selfMute = Color(0xFF7B8794);
}

class RoomBackgroundTheme {
  const RoomBackgroundTheme({
    required this.id,
    required this.name,
    required this.colors,
    required this.accent,
    this.assetPath,
  });

  final String id;
  final String name;
  final List<Color> colors;
  final Color accent;
  final String? assetPath;
}

const String roomBackgroundAssetBase = 'assets/images/rooms/backgrounds';

const RoomBackgroundTheme defaultRoomBackgroundTheme = RoomBackgroundTheme(
  id: 'default_luxury',
  name: 'Default Luxury',
  colors: [Color(0xFF050716), Color(0xFF171034), Color(0xFF0B0613)],
  accent: RoomColors.violet,
  assetPath: '$roomBackgroundAssetBase/default_luxury.png',
);

const RoomBackgroundTheme defaultDarkRoomBackgroundTheme = RoomBackgroundTheme(
  id: 'default_dark',
  name: 'Default Dark',
  colors: [Color(0xFF070414), Color(0xFF251538), Color(0xFF0A0710)],
  accent: RoomColors.gold,
  assetPath: '$roomBackgroundAssetBase/default_dark.png',
);

const RoomBackgroundTheme vibeSyncRoomBackgroundTheme = RoomBackgroundTheme(
  id: 'vibe_sync',
  name: 'VibeSync Glow',
  colors: [Color(0xFF16051F), Color(0xFF3A0D4E), Color(0xFF061B33)],
  accent: Color(0xFFFF4FB8),
  assetPath: '$roomBackgroundAssetBase/vibe_sync.png',
);

const List<RoomBackgroundTheme> mockRoomBackgroundThemes = [
  defaultRoomBackgroundTheme,
  defaultDarkRoomBackgroundTheme,
  vibeSyncRoomBackgroundTheme,
  RoomBackgroundTheme(
    id: 'royal_night',
    name: 'Royal Night',
    colors: [Color(0xFF070414), Color(0xFF251538), Color(0xFF0A0710)],
    accent: RoomColors.gold,
    assetPath: '$roomBackgroundAssetBase/royal_night.png',
  ),
  RoomBackgroundTheme(
    id: 'ocean_mood',
    name: 'Ocean Mood',
    colors: [Color(0xFF021419), Color(0xFF08384A), Color(0xFF041018)],
    accent: RoomColors.aqua,
    assetPath: '$roomBackgroundAssetBase/ocean_mood.png',
  ),
  RoomBackgroundTheme(
    id: 'rose_private',
    name: 'Rose Private',
    colors: [Color(0xFF120713), Color(0xFF3B102A), Color(0xFF08040A)],
    accent: RoomColors.coral,
    assetPath: '$roomBackgroundAssetBase/rose_private.png',
  ),
];

class RoomBackground extends StatelessWidget {
  const RoomBackground({super.key, this.theme = defaultRoomBackgroundTheme});

  final RoomBackgroundTheme theme;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _fallbackGradient(),
          if (theme.assetPath != null)
            Image.asset(
              theme.assetPath!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.34),
                  Colors.black.withValues(alpha: 0.62),
                ],
              ),
            ),
          ),
          Positioned(
            right: -150,
            top: 90,
            child: _GlowCircle(size: 315, color: theme.accent.withValues(alpha: 0.14)),
          ),
          Positioned(
            left: -115,
            bottom: 130,
            child: _GlowCircle(size: 230, color: RoomColors.aqua.withValues(alpha: 0.10)),
          ),
          Positioned(
            right: 52,
            bottom: -120,
            child: _GlowCircle(size: 235, color: RoomColors.coral.withValues(alpha: 0.08)),
          ),
          ...List.generate(18, (index) {
            final left = ((index * 47) % 360).toDouble();
            final top = (58 + ((index * 71) % 700)).toDouble();
            final size = 1.4 + (index % 3);
            return Positioned(
              left: left,
              top: top,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _fallbackGradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: theme.colors,
        ),
      ),
    );
  }
}

class RoomBackgroundPickerSheet extends StatelessWidget {
  const RoomBackgroundPickerSheet({
    super.key,
    required this.currentTheme,
    required this.onThemeSelected,
  });

  final RoomBackgroundTheme currentTheme;
  final ValueChanged<RoomBackgroundTheme> onThemeSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.62),
      padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.paddingOf(context).bottom + 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(width: 44),
          const SizedBox(height: 14),
          const Text(
            'Room Backgrounds',
            style: TextStyle(color: RoomColors.plum, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose an asset background for this room.',
            style: TextStyle(color: Color(0xFF82758E), fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: mockRoomBackgroundThemes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 124,
              ),
              itemBuilder: (context, index) {
                final theme = mockRoomBackgroundThemes[index];
                final selected = theme.id == currentTheme.id;
                return _BackgroundThemeTile(
                  theme: theme,
                  selected: selected,
                  onTap: () {
                    onThemeSelected(theme);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundThemeTile extends StatelessWidget {
  const _BackgroundThemeTile({required this.theme, required this.selected, required this.onTap});

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
            border: Border.all(color: selected ? theme.accent : RoomColors.softLine, width: selected ? 2 : 1),
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
                      Container(decoration: BoxDecoration(gradient: LinearGradient(colors: theme.colors))),
                      if (theme.assetPath != null)
                        Image.asset(
                          theme.assetPath!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      Container(color: Colors.black.withValues(alpha: 0.18)),
                      if (selected)
                        const Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
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
                style: const TextStyle(color: RoomColors.plum, fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key, this.width = 46, this.color});

  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(width: width, height: 5, decoration: BoxDecoration(color: color ?? const Color(0xFFD9D2CC), borderRadius: BorderRadius.circular(999))),
    );
  }
}

class RoundRoomButton extends StatelessWidget {
  const RoundRoomButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
    this.background,
    this.size = 38,
    this.iconSize = 20,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color? background;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background ?? Colors.white.withValues(alpha: 0.075),
      shape: const CircleBorder(),
      child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: size, height: size, child: Icon(icon, color: color, size: iconSize))),
    );
  }
}

class GradientIconBox extends StatelessWidget {
  const GradientIconBox({super.key, required this.icon, required this.colors, this.size = 48});

  final IconData icon;
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(size * 0.30), gradient: LinearGradient(colors: colors)),
      child: Icon(icon, color: Colors.white, size: size * 0.44),
    );
  }
}

class RoomToast {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, backgroundColor: RoomColors.plum));
  }
}
