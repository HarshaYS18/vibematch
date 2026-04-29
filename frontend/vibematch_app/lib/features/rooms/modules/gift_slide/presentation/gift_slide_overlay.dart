import 'package:flutter/material.dart';

import '../../../presentation/live_room_models.dart';
import '../../../presentation/widgets/room_gifts.dart';

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
      return ageSeconds <= 4;
    }).take(2).toList(growable: false);

    if (visibleSlides.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: visibleSlides.map((slide) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GiftSlideCardModule(
            slide: slide,
            onComboTap: () => onComboTap(slide),
          ),
        );
      }).toList(),
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
    final ageSeconds = (15 - slide.remainingSeconds).clamp(0, 15);
    final exitProgress = ageSeconds <= 2 ? 0.0 : ((ageSeconds - 2) / 2).clamp(0.0, 1.0).toDouble();

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: exitProgress),
      duration: const Duration(milliseconds: 780),
      curve: Curves.easeInOutCubic,
      builder: (context, value, child) {
        final opacity = (1 - value).clamp(0.0, 1.0);
        final scale = 1.0 - (value * 0.06);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(-value * 190, 0),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.92, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.scale(scale: value, child: child),
          );
        },
        child: GestureDetector(
          onTap: onComboTap,
          child: Container(
            width: 286,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.48),
                  slide.colors.first.withValues(alpha: 0.38),
                  slide.colors.last.withValues(alpha: 0.34),
                  Colors.white.withValues(alpha: 0.14),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.58), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: slide.colors.first.withValues(alpha: 0.42),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: slide.colors.last.withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.32),
                            Colors.white.withValues(alpha: 0.05),
                            slide.colors.first.withValues(alpha: 0.10),
                            Colors.white.withValues(alpha: 0.18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    top: -22,
                    child: Transform.rotate(
                      angle: -0.42,
                      child: Container(
                        width: 46,
                        height: 118,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: 0.54),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      GiftVisual(
                        icon: slide.giftIcon,
                        colors: slide.colors,
                        assetPath: slide.giftAssetPath,
                        size: 40,
                        padding: 2,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${slide.senderName} sent ${slide.receiverName} ${slide.giftName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            height: 1.1,
                            shadows: [
                              Shadow(color: Colors.black45, blurRadius: 7),
                              Shadow(color: Colors.white54, blurRadius: 10),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.50)),
                        ),
                        child: Text(
                          'x${slide.combo}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            shadows: [Shadow(color: Colors.white70, blurRadius: 8)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
