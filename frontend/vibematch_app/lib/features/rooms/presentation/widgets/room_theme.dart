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
  });

  final String id;
  final String name;
  final List<Color> colors;
  final Color accent;
}

const RoomBackgroundTheme defaultRoomBackgroundTheme = RoomBackgroundTheme(
  id: 'nebula_glow',
  name: 'Nebula Glow',
  colors: [Color(0xFF050716), Color(0xFF171034), Color(0xFF0B0613)],
  accent: RoomColors.violet,
);

const RoomBackgroundTheme vibeSyncRoomBackgroundTheme = RoomBackgroundTheme(
  id: 'vibesync_neon_rose',
  name: 'VibeSync Neon Rose',
  colors: [Color(0xFF16051F), Color(0xFF3A0D4E), Color(0xFF061B33)],
  accent: Color(0xFFFF4FB8),
);

const List<RoomBackgroundTheme> mockRoomBackgroundThemes = [
  defaultRoomBackgroundTheme,
  vibeSyncRoomBackgroundTheme,
  RoomBackgroundTheme(
    id: 'royal_night',
    name: 'Royal Night',
    colors: [Color(0xFF070414), Color(0xFF251538), Color(0xFF0A0710)],
    accent: RoomColors.gold,
  ),
  RoomBackgroundTheme(
    id: 'ocean_mood',
    name: 'Ocean Mood',
    colors: [Color(0xFF021419), Color(0xFF08384A), Color(0xFF041018)],
    accent: RoomColors.aqua,
  ),
  RoomBackgroundTheme(
    id: 'rose_private',
    name: 'Rose Private',
    colors: [Color(0xFF120713), Color(0xFF3B102A), Color(0xFF08040A)],
    accent: RoomColors.coral,
  ),
];

class RoomBackground extends StatelessWidget {
  const RoomBackground({super.key, this.theme = defaultRoomBackgroundTheme});

  final RoomBackgroundTheme theme;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.colors,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -150,
              top: 90,
              child: _GlowCircle(
                size: 315,
                color: theme.accent.withValues(alpha: 0.18),
              ),
            ),
            Positioned(
              left: -115,
              bottom: 130,
              child: _GlowCircle(
                size: 230,
                color: RoomColors.aqua.withValues(alpha: 0.12),
              ),
            ),
            Positioned(
              right: 52,
              bottom: -120,
              child: _GlowCircle(
                size: 235,
                color: RoomColors.coral.withValues(alpha: 0.10),
              ),
            ),
            ...List.generate(26, (index) {
              final left = ((index * 47) % 360).toDouble();
              final top = (58 + ((index * 71) % 700)).toDouble();
              final size = 1.8 + (index % 3);
              return Positioned(
                left: left,
                top: top,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ],
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key, this.width = 46, this.color});

  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: width,
        height: 5,
        decoration: BoxDecoration(
          color: color ?? const Color(0xFFD9D2CC),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
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
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: color, size: iconSize),
        ),
      ),
    );
  }
}

class GradientIconBox extends StatelessWidget {
  const GradientIconBox({
    super.key,
    required this.icon,
    required this.colors,
    this.size = 48,
  });

  final IconData icon;
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.30),
        gradient: LinearGradient(colors: colors),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.44),
    );
  }
}

class RoomToast {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: RoomColors.plum,
      ),
    );
  }
}
