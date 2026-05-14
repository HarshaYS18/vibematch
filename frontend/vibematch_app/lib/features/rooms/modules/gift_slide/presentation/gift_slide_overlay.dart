import 'package:flutter/material.dart';

import '../../../presentation/live_room_models.dart';
import '../../../presentation/widgets/room_gifts.dart';

class GiftSlideOverlay extends StatelessWidget {
  const GiftSlideOverlay({
    super.key,
    required this.slides,
    required this.onComboTap,
    this.topFactor = 0.38,
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
            padding: const EdgeInsets.only(bottom: 7),
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
    final accent = _accentForSlide(slide);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: -1.0, end: exitProgress),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final isEntering = value < 0;
        final enterProgress = (value + 1).clamp(0.0, 1.0).toDouble();
        final exitValue = value.clamp(0.0, 1.0).toDouble();
        final opacity = isEntering ? enterProgress : (1 - exitValue).clamp(0.0, 1.0).toDouble();
        final dx = isEntering ? -320 + (320 * enterProgress) : -exitValue * 250;
        final scale = isEntering ? 0.96 + (0.04 * enterProgress) : 1.0 - (exitValue * 0.035);

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
          width: 314,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withValues(alpha: 0.00),
                Colors.black.withValues(alpha: 0.54),
                Colors.black.withValues(alpha: 0.64),
                Colors.black.withValues(alpha: 0.54),
                Colors.black.withValues(alpha: 0.00),
              ],
              stops: const [0.0, 0.12, 0.50, 0.88, 1.0],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.8),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 35,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 7),
              GiftVisual(
                icon: slide.giftIcon,
                colors: slide.colors,
                assetPath: slide.giftAssetPath,
                size: 40,
                padding: 2,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '${slide.senderName} sent ${slide.receiverName} ${slide.giftName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.60), width: 0.8),
                ),
                child: Text(
                  'x${slide.combo}',
                  style: TextStyle(
                    color: accent == Colors.white ? Colors.white : accent,
                    fontSize: 12,
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
