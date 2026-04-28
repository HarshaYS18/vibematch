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
    required this.assetPath,
    required this.accent,
  });

  final String id;
  final String name;
  final String assetPath;
  final Color accent;

  List<Color> get colors => [RoomColors.deep, RoomColors.deep];
}

const String roomBackgroundAssetBase = 'assets/images/rooms/backgrounds';

const RoomBackgroundTheme defaultRoomBackgroundTheme = RoomBackgroundTheme(
  id: 'default_luxury',
  name: 'Default Luxury',
  assetPath: '$roomBackgroundAssetBase/default_luxury.png',
  accent: RoomColors.violet,
);

const RoomBackgroundTheme defaultDarkRoomBackgroundTheme = RoomBackgroundTheme(
  id: 'default_dark',
  name: 'Default Dark',
  assetPath: '$roomBackgroundAssetBase/default_dark.png',
  accent: RoomColors.gold,
);

const List<RoomBackgroundTheme> ownedRoomBackgroundThemes = [
  defaultRoomBackgroundTheme,
  defaultDarkRoomBackgroundTheme,
];

const List<RoomBackgroundTheme> mockRoomBackgroundThemes = ownedRoomBackgroundThemes;

final ValueNotifier<RoomBackgroundTheme> activeRoomBackgroundTheme = ValueNotifier<RoomBackgroundTheme>(
  defaultRoomBackgroundTheme,
);

class RoomBackground extends StatelessWidget {
  const RoomBackground({super.key, this.theme = defaultRoomBackgroundTheme});

  final RoomBackgroundTheme theme;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    return RepaintBoundary(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minWidth: screenSize.width,
        maxWidth: screenSize.width,
        minHeight: screenSize.height,
        maxHeight: screenSize.height,
        child: SizedBox(
          width: screenSize.width,
          height: screenSize.height,
          child: _AssetOnlyRoomBackground(theme: theme),
        ),
      ),
    );
  }
}

class _AssetOnlyRoomBackground extends StatelessWidget {
  const _AssetOnlyRoomBackground({required this.theme});

  final RoomBackgroundTheme theme;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: RoomColors.deep),
        Image.asset(
          theme.assetPath,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (context, error, stackTrace) => Container(color: RoomColors.deep),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.05),
                Colors.black.withValues(alpha: 0.16),
                Colors.black.withValues(alpha: 0.50),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class RoomBackgroundPickerSheet extends StatelessWidget {
  const RoomBackgroundPickerSheet({
    super.key,
    required this.currentTheme,
    required this.onThemeSelected,
    required this.onStoreTap,
  });

  final RoomBackgroundTheme currentTheme;
  final ValueChanged<RoomBackgroundTheme> onThemeSelected;
  final VoidCallback onStoreTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.62,
      padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.paddingOf(context).bottom + 14),
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
                      'Room Backgrounds',
                      style: TextStyle(color: RoomColors.plum, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Owned asset backgrounds only',
                      style: TextStyle(color: Color(0xFF82758E), fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              _StorePill(onTap: onStoreTap),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Owned',
            style: TextStyle(color: RoomColors.plum, fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              itemCount: ownedRoomBackgroundThemes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.18,
              ),
              itemBuilder: (context, index) {
                final theme = ownedRoomBackgroundThemes[index];
                final selected = theme.id == currentTheme.id;
                return _BackgroundThemeTile(
                  theme: theme,
                  selected: selected,
                  onTap: () {
                    activeRoomBackgroundTheme.value = theme;
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
                      Container(color: RoomColors.deep),
                      Image.asset(
                        theme.assetPath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(color: RoomColors.deep),
                      ),
                      Container(color: Colors.black.withValues(alpha: 0.12)),
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

class _StorePill extends StatelessWidget {
  const _StorePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RoomColors.plum,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_rounded, color: Colors.white, size: 14),
              SizedBox(width: 5),
              Text('Store', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
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
      child: Container(width: width, height: 5, decoration: BoxDecoration(color: color ?? const Color(0xFFD9D2CC), borderRadius: BorderRadius.circular(999))),
    );
  }
}

class RoundRoomButton extends StatefulWidget {
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
  State<RoundRoomButton> createState() => _RoundRoomButtonState();
}

class _RoundRoomButtonState extends State<RoundRoomButton> {
  bool _tapLocked = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.background ?? Colors.white.withValues(alpha: 0.075),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          if (_tapLocked) return;
          _tapLocked = true;
          widget.onTap();
          Future<void>.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _tapLocked = false;
          });
        },
        child: SizedBox(width: widget.size, height: widget.size, child: Icon(widget.icon, color: widget.color, size: widget.iconSize)),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, backgroundColor: RoomColors.plum));
  }
}
