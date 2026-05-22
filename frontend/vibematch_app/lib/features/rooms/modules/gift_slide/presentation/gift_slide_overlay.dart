import 'package:flutter/material.dart';

import '../../../presentation/live_room_models.dart';
import '../../../presentation/widgets/gift_modules/gift_visual.dart';

class GiftSlideOverlay extends StatelessWidget {
  const GiftSlideOverlay({
    super.key,
    required this.slides,
    required this.onComboTap,
    this.topFactor = 0.39,
  });

  final List<GiftSlide> slides;
  final ValueChanged<GiftSlide> onComboTap;
  final double topFactor;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Positioned(
      left: 0,
      right: 0,
      top: size.height * topFactor,
      child: GiftSlideStackModule(slides: slides, onComboTap: onComboTap),
    );
  }
}

class GiftSlideStackModule extends StatelessWidget {
  const GiftSlideStackModule({super.key, required this.slides, required this.onComboTap});

  final List<GiftSlide> slides;
  final ValueChanged<GiftSlide> onComboTap;

  @override
  Widget build(BuildContext context) {
    final visibleSlides = slides.where((slide) {
      final ageSeconds = (15 - slide.remainingSeconds).clamp(0, 15);
      return ageSeconds <= 5;
    }).take(1).toList(growable: false);
    if (visibleSlides.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final slide in visibleSlides)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: GiftSlideCardModule(
                key: ValueKey(slide.id),
                slide: slide,
                onComboTap: () => onComboTap(slide),
              ),
            ),
        ],
      ),
    );
  }
}

class GiftSlideCardModule extends StatelessWidget {
  const GiftSlideCardModule({super.key, required this.slide, required this.onComboTap});

  final GiftSlide slide;
  final VoidCallback onComboTap;

  @override
  Widget build(BuildContext context) {
    final ageSeconds = (15 - slide.remainingSeconds).clamp(0, 15).toDouble();
    const holdSeconds = 3.25;
    final exitProgress = ageSeconds <= holdSeconds
        ? 0.0
        : ((ageSeconds - holdSeconds) / 1.15).clamp(0.0, 1.0).toDouble();
    final accent = _accentForSlide(slide);
    final isLucky = _isLuckySlide(slide);
    final label = _comboLabel(slide);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0 + exitProgress),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final enter = value.clamp(0.0, 1.0).toDouble();
        final exit = (value - 1.0).clamp(0.0, 1.0).toDouble();
        final enterCurve = Curves.easeOutCubic.transform(enter);
        final exitCurve = Curves.easeInCubic.transform(exit);
        final opacity = exit > 0 ? 1 - exitCurve : enterCurve;
        final dx = exit > 0 ? -260 * exitCurve : 320 * (1 - enterCurve);
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.scale(scale: 0.985 + (0.015 * enterCurve), child: child),
          ),
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onComboTap,
        child: SizedBox(
          width: 298,
          height: 47,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                left: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.02),
                        const Color(0xDD18111F),
                        const Color(0xE621182E),
                        Colors.black.withValues(alpha: 0.04),
                      ],
                      stops: const [0, 0.16, 0.78, 1],
                    ),
                    border: Border.all(
                      color: accent.withValues(alpha: isLucky ? 0.34 : 0.16),
                      width: 0.7,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                      if (isLucky)
                        BoxShadow(
                          color: accent.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 3),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 3,
                child: GiftVisual(
                  icon: slide.giftIcon,
                  colors: slide.colors,
                  assetPath: slide.giftAssetPath,
                  assetUrl: slide.giftAssetUrl,
                  size: 41,
                  padding: 2,
                ),
              ),
              Positioned(
                left: 49,
                right: 54,
                top: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slide.senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.8,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'sent ${slide.giftName} to ${slide.receiverName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontSize: 9.7,
                        height: 1,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 8,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: accent.withValues(alpha: isLucky ? 0.18 : 0.12),
                    border: Border.all(
                      color: accent.withValues(alpha: isLucky ? 0.44 : 0.24),
                      width: 0.7,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: accent,
                      fontSize: isLucky ? 11.2 : 10.6,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
              if (isLucky) Positioned(right: 46, top: -3, child: _LuckyPulse(color: accent)),
            ],
          ),
        ),
      ),
    );
  }

  bool _isLuckySlide(GiftSlide slide) {
    final text = '${slide.giftName} ${slide.giftName.toLowerCase()}';
    return text.contains('lucky') ||
        text.contains('packet') ||
        text.contains('spin') ||
        RegExp(r'x(0|1|2|5|10|20|50|100|500|1000)').hasMatch(text.toLowerCase());
  }

  String _comboLabel(GiftSlide slide) {
    final lower = slide.giftName.toLowerCase();
    final match = RegExp(r'x(1000|500|100|50|20|10|5|2|1|0)').firstMatch(lower);
    if (match != null) return '${match.group(1)}x';
    return 'x${slide.combo}';
  }

  Color _accentForSlide(GiftSlide slide) {
    final name = slide.giftName.toLowerCase();
    if (name.contains('x1000')) return const Color(0xFF22D3EE);
    if (name.contains('x500')) return const Color(0xFFFF2D95);
    if (name.contains('x100')) return const Color(0xFFFFD166);
    if (name.contains('x0') || name.contains('try again')) return const Color(0xFFB9ADC8);
    if (name.contains('lucky') || name.contains('packet') || name.contains('spin')) {
      return const Color(0xFFFFB545);
    }
    return Colors.white;
  }
}

class _LuckyPulse extends StatelessWidget {
  const _LuckyPulse({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.72, end: 1.0),
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeInOut,
      builder: (context, value, child) => Opacity(
        opacity: 1 - ((value - 0.72) / 0.28).clamp(0.0, 1.0) * 0.45,
        child: Transform.scale(scale: value, child: child),
      ),
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 9)],
        ),
      ),
    );
  }
}