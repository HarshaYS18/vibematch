import 'package:flutter/material.dart';

enum RibbonBackgroundType {
  royalGold,
  lovePink,
  darkLuxury,
  svipPurple,
  luckyFlash,
  aquaPremium,
  cricketGreen,
}

class RibbonBackgroundStyle {
  final RibbonBackgroundType type;
  final String label;
  final List<Color> bodyColors;
  final List<Color> borderColors;
  final List<Color> foldColors;
  final Color glowColor;
  final Color iconOuterStart;
  final Color iconOuterMiddle;
  final Color iconOuterEnd;
  final Color iconInnerStart;
  final Color iconInnerEnd;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color coinTextColor;
  final IconData badgeIcon;

  const RibbonBackgroundStyle({
    required this.type,
    required this.label,
    required this.bodyColors,
    required this.borderColors,
    required this.foldColors,
    required this.glowColor,
    required this.iconOuterStart,
    required this.iconOuterMiddle,
    required this.iconOuterEnd,
    required this.iconInnerStart,
    required this.iconInnerEnd,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.coinTextColor,
    required this.badgeIcon,
  });

  static RibbonBackgroundStyle fromType(RibbonBackgroundType type) {
    switch (type) {
      case RibbonBackgroundType.royalGold:
        return const RibbonBackgroundStyle(
          type: RibbonBackgroundType.royalGold,
          label: 'Royal Gold',
          bodyColors: [Color(0xFF2A1707), Color(0xFF7A4A13), Color(0xFFFFC857), Color(0xFF4A2608)],
          borderColors: [Color(0xFFFFF0B8), Color(0xFFFFC857), Color(0xFFFFF0B8)],
          foldColors: [Color(0xFFB7791F), Color(0xFF3B2109)],
          glowColor: Color(0xFFFFD66B),
          iconOuterStart: Color(0xFFFFF4B8),
          iconOuterMiddle: Color(0xFFE8B84A),
          iconOuterEnd: Color(0xFF9F6719),
          iconInnerStart: Color(0xFF4D2A10),
          iconInnerEnd: Color(0xFF160A02),
          primaryTextColor: Color(0xFFFFF0B8),
          secondaryTextColor: Color(0xFFFFFFFF),
          coinTextColor: Color(0xFFFFE7A0),
          badgeIcon: Icons.workspace_premium_rounded,
        );
      case RibbonBackgroundType.lovePink:
        return const RibbonBackgroundStyle(
          type: RibbonBackgroundType.lovePink,
          label: 'Love Pink',
          bodyColors: [Color(0xFF3B1022), Color(0xFFE84C72), Color(0xFFFF8AB3), Color(0xFF6D1D43)],
          borderColors: [Color(0xFFFFD1E4), Color(0xFFFF7DAE), Color(0xFFFFE6F1)],
          foldColors: [Color(0xFFFF70A6), Color(0xFF3B1022)],
          glowColor: Color(0xFFFF6B9E),
          iconOuterStart: Color(0xFFFFD1E4),
          iconOuterMiddle: Color(0xFFFF6B9E),
          iconOuterEnd: Color(0xFF9B174D),
          iconInnerStart: Color(0xFF7B1D49),
          iconInnerEnd: Color(0xFF220812),
          primaryTextColor: Color(0xFFFFD1E4),
          secondaryTextColor: Color(0xFFFFFFFF),
          coinTextColor: Color(0xFFFFF0B8),
          badgeIcon: Icons.favorite_rounded,
        );
      case RibbonBackgroundType.darkLuxury:
        return const RibbonBackgroundStyle(
          type: RibbonBackgroundType.darkLuxury,
          label: 'Dark Luxury',
          bodyColors: [Color(0xFF05030A), Color(0xFF171123), Color(0xFF312145), Color(0xFF090512)],
          borderColors: [Color(0xFFBBA7FF), Color(0xFF5DE2D6), Color(0xFFFFD66B)],
          foldColors: [Color(0xFF241832), Color(0xFF06030A)],
          glowColor: Color(0xFF8C7CFF),
          iconOuterStart: Color(0xFFBBA7FF),
          iconOuterMiddle: Color(0xFF5DE2D6),
          iconOuterEnd: Color(0xFF322358),
          iconInnerStart: Color(0xFF181021),
          iconInnerEnd: Color(0xFF030106),
          primaryTextColor: Color(0xFFBBA7FF),
          secondaryTextColor: Color(0xFFFFFFFF),
          coinTextColor: Color(0xFFFFD66B),
          badgeIcon: Icons.auto_awesome_rounded,
        );
      case RibbonBackgroundType.svipPurple:
        return const RibbonBackgroundStyle(
          type: RibbonBackgroundType.svipPurple,
          label: 'SVIP Purple',
          bodyColors: [Color(0xFF241047), Color(0xFF6D3DA0), Color(0xFFB765FF), Color(0xFF351452)],
          borderColors: [Color(0xFFE7D2FF), Color(0xFFFFD66B), Color(0xFFE7D2FF)],
          foldColors: [Color(0xFF8C5CF6), Color(0xFF20112F)],
          glowColor: Color(0xFFB765FF),
          iconOuterStart: Color(0xFFE7D2FF),
          iconOuterMiddle: Color(0xFFB765FF),
          iconOuterEnd: Color(0xFF55308A),
          iconInnerStart: Color(0xFF4D2A73),
          iconInnerEnd: Color(0xFF160A24),
          primaryTextColor: Color(0xFFE7D2FF),
          secondaryTextColor: Color(0xFFFFFFFF),
          coinTextColor: Color(0xFFFFE7A0),
          badgeIcon: Icons.diamond_rounded,
        );
      case RibbonBackgroundType.luckyFlash:
        return const RibbonBackgroundStyle(
          type: RibbonBackgroundType.luckyFlash,
          label: 'Lucky Flash',
          bodyColors: [Color(0xFF331000), Color(0xFFFF6A00), Color(0xFFFFD43B), Color(0xFF661D00)],
          borderColors: [Color(0xFFFFF2A8), Color(0xFFFF6A00), Color(0xFFFFF2A8)],
          foldColors: [Color(0xFFFF8A00), Color(0xFF3A1100)],
          glowColor: Color(0xFFFFA000),
          iconOuterStart: Color(0xFFFFF2A8),
          iconOuterMiddle: Color(0xFFFFA000),
          iconOuterEnd: Color(0xFF9B3300),
          iconInnerStart: Color(0xFF612000),
          iconInnerEnd: Color(0xFF200900),
          primaryTextColor: Color(0xFFFFF2A8),
          secondaryTextColor: Color(0xFFFFFFFF),
          coinTextColor: Color(0xFFFFF2A8),
          badgeIcon: Icons.bolt_rounded,
        );
      case RibbonBackgroundType.aquaPremium:
        return const RibbonBackgroundStyle(
          type: RibbonBackgroundType.aquaPremium,
          label: 'Aqua Premium',
          bodyColors: [Color(0xFF042B2C), Color(0xFF12C7B7), Color(0xFF64FFF0), Color(0xFF063E4B)],
          borderColors: [Color(0xFFCFFFFB), Color(0xFF12C7B7), Color(0xFFFFD66B)],
          foldColors: [Color(0xFF12C7B7), Color(0xFF05272D)],
          glowColor: Color(0xFF12C7B7),
          iconOuterStart: Color(0xFFCFFFFB),
          iconOuterMiddle: Color(0xFF12C7B7),
          iconOuterEnd: Color(0xFF08656A),
          iconInnerStart: Color(0xFF063E4B),
          iconInnerEnd: Color(0xFF031316),
          primaryTextColor: Color(0xFFCFFFFB),
          secondaryTextColor: Color(0xFFFFFFFF),
          coinTextColor: Color(0xFFFFE7A0),
          badgeIcon: Icons.waves_rounded,
        );
      case RibbonBackgroundType.cricketGreen:
        return const RibbonBackgroundStyle(
          type: RibbonBackgroundType.cricketGreen,
          label: 'Cricket Green',
          bodyColors: [Color(0xFF072414), Color(0xFF0D8A48), Color(0xFF5BFF9E), Color(0xFF113A1F)],
          borderColors: [Color(0xFFD8FFE6), Color(0xFF5BFF9E), Color(0xFFFFD66B)],
          foldColors: [Color(0xFF0D8A48), Color(0xFF061C10)],
          glowColor: Color(0xFF5BFF9E),
          iconOuterStart: Color(0xFFD8FFE6),
          iconOuterMiddle: Color(0xFF5BFF9E),
          iconOuterEnd: Color(0xFF0D8A48),
          iconInnerStart: Color(0xFF113A1F),
          iconInnerEnd: Color(0xFF041108),
          primaryTextColor: Color(0xFFD8FFE6),
          secondaryTextColor: Color(0xFFFFFFFF),
          coinTextColor: Color(0xFFFFE7A0),
          badgeIcon: Icons.sports_cricket_rounded,
        );
    }
  }
}
