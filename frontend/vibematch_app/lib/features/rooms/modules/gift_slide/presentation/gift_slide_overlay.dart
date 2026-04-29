import 'package:flutter/material.dart';

import '../../../presentation/live_room_models.dart';
import '../../../presentation/widgets/room_gifts.dart';

class GiftSlideOverlay extends StatelessWidget {
  const GiftSlideOverlay({
    super.key,
    required this.slides,
    required this.onComboTap,
    this.topFactor = 0.30,
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
      return ageSeconds <= 7;
    }).take(3).toList(growable: false);

    if (visibleSlides.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      ignoring: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: visibleSlides.map((slide) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
    final exitProgress = ageSeconds <= 5 ? 0.0 : ((ageSeconds - 5) / 2).clamp(0.0, 1.0).toDouble();

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: -1.0, end: exitProgress),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final isEntering = value < 0;
        final enterProgress = (value + 1).clamp(0.0, 1.0).toDouble();
        final exitValue = value.clamp(0.0, 1.0).toDouble();
        final opacity = isEntering ? enterProgress : (1 - exitValue).clamp(0.0, 1.0).toDouble();
        final dx = isEntering ? -340 + (340 * enterProgress) : -exitValue * 260;
        final scale = isEntering ? 0.86 + (0.14 * enterProgress) : 1.0 - (exitValue * 0.05);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: GestureDetector(
        onTap: onComboTap,
        child: Container(
          width: 306,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.58),
                slide.colors.first.withValues(alpha: 0.50),
                slide.colors.last.withValues(alpha: 0.42),
                Colors.white.withValues(alpha: 0.16),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.70), width: 1.3),
            boxShadow: [
              BoxShadow(
                color: slide.colors.first.withValues(alpha: 0.52),
                blurRadius: 34,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: slide.colors.last.withValues(alpha: 0.34),
                blurRadius: 24,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.36),
                          Colors.white.withValues(alpha: 0.07),
                          slide.colors.first.withValues(alpha: 0.12),
                          Colors.white.withValues(alpha: 0.20),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -2,
                  top: -24,
                  child: Transform.rotate(
                    angle: -0.42,
                    child: Container(
                      width: 54,
                      height: 128,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.72),
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
                      size: 44,
                      padding: 2,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '${slide.senderName} sent ${slide.receiverName} ${slide.giftName}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          height: 1.1,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 8),
                            Shadow(color: Colors.white60, blurRadius: 12),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
                      ),
                      child: Text(
                        'x${slide.combo}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
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
    );
  }
}
