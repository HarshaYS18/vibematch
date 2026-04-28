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
    this.overlayOpacity = 0.42,
  });

  final String id;
  final String name;

  /// Fallback colors only. The actual room background should come from assets.
  final List<Color> colors;
  final Color accent;

  /// Local packaged background asset.
  ///
  /// Later this can be replaced by approved backend/custom theme URLs, but the
  /// base live room should never hardcode visual backgrounds inside LiveRoomPage.
  final String? assetPath;
  final double overlayOpacity;
}

const String roomBackgroundAssetBase = 'assets/images/rooms/backgrounds';

const RoomBackgroundTheme defaultRoomBackgroundTheme = RoomBackgroundTheme(
  id: 'default_luxury',
  name: 'Default Luxury',
  assetPath: '$roomBackgroundAssetBase/default_luxury.png',
  colors: [Color(0xFF050716), Color(0xFF171034), Color(0xFF0B0613)],
  accent: RoomColors.violet,
);

const List<RoomBackgroundTheme> mockRoomBackgroundThemes = [
  defaultRoomBackgroundTheme,
  RoomBackgroundTheme(
    id: 'royal_night',
    name: 'Royal Night',
    assetPath: '$roomBackgroundAssetBase/royal_night.png',
    colors: [Color(0xFF070414), Color(0xFF251538), Color(0xFF0A0710)],
    accent: RoomColors.gold,
  ),
  RoomBackgroundTheme(
    id: 'neon_night',
    name: 'Neon Night',
    assetPath: '$roomBackgroundAssetBase/neon_night.png',
    colors: [Color(0xFF071015), Color(0xFF10284A), Color(0xFF080611)],
    accent: RoomColors.aqua,
  ),
  RoomBackgroundTheme(
    id: 'rose_private',
    name: 'Rose Private',
    assetPath: '$roomBackgroundAssetBase/rose_private.png',
    colors: [Color(0xFF120713), Color(0xFF3B102A), Color(0xFF08040A)],
    accent: RoomColors.coral,
  ),
  RoomBackgroundTheme(
    id: 'cricket_mode',
    name: 'Cricket Mode',
    assetPath: '$roomBackgroundAssetBase/cricket_mode.png',
    colors: [Color(0xFF04150B), Color(0xFF0F3B22), Color(0xFF050B08)],
    accent: Color(0xFF4ADE80),
  ),
  RoomBackgroundTheme(
    id: 'watch_party',
    name: 'Watch Party',
    assetPath: '$roomBackgroundAssetBase/watch_party.png',
    colors: [Color(0xFF05050B), Color(0xFF111827), Color(0xFF020617)],
    accent: Color(0xFF60A5FA),
  ),
];

class RoomBackground extends StatelessWidget {
  const RoomBackground({
    super.key,
    this.theme = defaultRoomBackgroundTheme,
    this.customAssetPath,
    this.overlayOpacity,
  });

  final RoomBackgroundTheme theme;

  /// Optional override used later for approved custom room backgrounds.
  final String? customAssetPath;
  final double? overlayOpacity;

  @override
  Widget build(BuildContext context) {
    final assetPath = customAssetPath ?? theme.assetPath;
    final effectiveOverlayOpacity = overlayOpacity ?? theme.overlayOpacity;

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _FallbackGradient(theme: theme),
          if (assetPath != null)
            Image.asset(
              assetPath,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: effectiveOverlayOpacity * 0.70),
                  Colors.black.withValues(alpha: effectiveOverlayOpacity),
                  Colors.black.withValues(alpha: (effectiveOverlayOpacity + 0.16).clamp(0.0, 0.82)),
                ],
              ),
            ),
          ),
          _RoomAtmosphere(theme: theme),
        ],
      ),
    );
  }
}

class _FallbackGradient extends StatelessWidget {
  const _FallbackGradient({required this.theme});

  final RoomBackgroundTheme theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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

class _RoomAtmosphere extends StatelessWidget {
  const _RoomAtmosphere({required this.theme});

  final RoomBackgroundTheme theme;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(right: -150, top: 90, child: _GlowCircle(size: 315, color: theme.accent.withValues(alpha: 0.16))),
          Positioned(left: -115, bottom: 130, child: _GlowCircle(size: 230, color: RoomColors.aqua.withValues(alpha: 0.10))),
          Positioned(right: 52, bottom: -120, child: _GlowCircle(size: 235, color: RoomColors.coral.withValues(alpha: 0.08))),
          ...List.generate(22, (index) {
            final left = ((index * 47) % 360).toDouble();
            final top = (58 + ((index * 71) % 700)).toDouble();
            final size = 1.6 + (index % 3);
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
  const SheetHandle({super.key, this.width = 46});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: width,
        height: 5,
        decoration: BoxDecoration(color: const Color(0xFFD9D2CC), borderRadius: BorderRadius.circular(999)),
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
        child: SizedBox(width: size, height: size, child: Icon(icon, color: color, size: iconSize)),
      ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, backgroundColor: RoomColors.plum),
    );
  }
}
