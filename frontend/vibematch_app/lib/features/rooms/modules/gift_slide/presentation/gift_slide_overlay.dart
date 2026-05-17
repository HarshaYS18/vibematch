import 'package:flutter/material.dart';

import '../../../presentation/live_room_models.dart';
import '../../../presentation/widgets/gift_modules/gift_visual.dart';

class GiftSlideOverlay extends StatelessWidget {
  const GiftSlideOverlay({
    super.key,
    required this.slides,
    required this.onComboTap,
    this.topFactor = 0.42,
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
      child: GiftSlideStackModule(
        slides: slides,
        onComboTap: onComboTap,
      ),
    );
  }
}

class GiftSlideStackModule extends StatelessWidget {
  const GiftSlideStackModule({
    super.key,
    required this.slides,
    required this.onComboTap,
  });

  final List<GiftSlide> slides;
  final ValueChanged<GiftSlide> onComboTap;

  @override
  Widget build(BuildContext context) {
    final visibleSlides = slides.where((slide) {
      final ageSeconds = (15 - slide.remainingSeconds).clamp(0, 15);
      return ageSeconds <= 6;
    }).take(1).toList(growable: false);

    if (visibleSlides.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      ignoring: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: visibleSlides.map((slide) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: GiftSlideCardModule(
              key: ValueKey(slide.id),
              slide: slide,
              onComboTap: () => onComboTap(slide),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class GiftSlideCardModule extends StatelessWidget {
  const GiftSlideCardModule({
    super.key,
    required this.slide,
    required this.onComboTap,
  });

  final GiftSlide slide;
  final VoidCallback onComboTap;

  @override
  Widget build(BuildContext context) {
    final ageSeconds = (15 - slide.remainingSeconds).clamp(0, 15).toDouble();
    final holdSeconds = 3.8;
    final exitProgress = ageSeconds <= holdSeconds ? 0.0 : ((ageSeconds - holdSeconds) / 1.6).clamp(0.0, 1.0).toDouble();
    final accent = _accentForSlide(slide);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0 + exitProgress),
      duration: const Duration(milliseconds: 660),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        final enterProgress = value.clamp(0.0, 1.0).toDouble();
        final exitValue = (value - 1.0).clamp(0.0, 1.0).toDouble();
        final enterCurve = Curves.easeOutCubic.transform(enterProgress);
        final exitCurve = Curves.easeInCubic.transform(exitValue);
        final opacity = exitValue > 0 ? (1 - exitCurve).clamp(0.0, 1.0).toDouble() : enterCurve;
        final dx = exitValue > 0 ? -360 * exitCurve : 390 * (1 - enterCurve);
        final scale = exitValue > 0 ? 1.0 - (exitCurve * 0.025) : 0.97 + (0.03 * enterCurve);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onComboTap,
        child: Container(
          width: 286,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withValues(alpha: 0.00),
                Colors.black.withValues(alpha: 0.48),
                Colors.black.withValues(alpha: 0.62),
                Colors.black.withValues(alpha: 0.48),
                Colors.black.withValues(alpha: 0.00),
              ],
              stops: const [0.0, 0.13, 0.50, 0.87, 1.0],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 2.5,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 6),
              GiftVisual(
                icon: slide.giftIcon,
                colors: slide.colors,
                assetPath: slide.giftAssetPath,
                assetUrl: slide.giftAssetUrl,
                size: 34,
                padding: 2,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${slide.senderName} sent ${slide.receiverName} ${slide.giftName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.4,
                    height: 1.05,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.46), width: 0.7),
                ),
                child: Text(
                  'x${slide.combo}',
                  style: TextStyle(
                    color: accent == Colors.white ? Colors.white : accent,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accentForSlide(GiftSlide slide) {
    final name = slide.giftName.toLowerCase();
    if (name.contains('x1000')) return const Color(0xFF22D3EE);
    if (name.contains('x500')) return const Color(0xFFFF2D95);
    if (name.contains('x100')) return const Color(0xFFFFD166);
    return Colors.white;
  }
}
