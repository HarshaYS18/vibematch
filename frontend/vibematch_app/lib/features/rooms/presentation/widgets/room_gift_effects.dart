import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_theme.dart';

/// Future gift video/effect layer.
///
/// Keep full-screen video gift effects, Lottie/Rive effects, sound triggers,
/// and queue handling inside this module instead of mixing them into
/// live_room_page.dart or room_gifts.dart.
class GiftEffectStage extends StatelessWidget {
  const GiftEffectStage({
    super.key,
    required this.activeSlides,
  });

  final List<GiftSlide> activeSlides;

  @override
  Widget build(BuildContext context) {
    if (activeSlides.isEmpty) return const SizedBox.shrink();
    final latest = activeSlides.first;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.center,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: 0.12,
          child: Icon(latest.giftIcon, color: RoomColors.gold, size: 120),
        ),
      ),
    );
  }
}

class GiftEffectQueueController {
  const GiftEffectQueueController();

  // Backend/socket hook later:
  // - enqueue normal gift slide
  // - enqueue combo buzzer
  // - enqueue full-screen video effect
  // - play effect sound
  // - serialize effects one after another to avoid overlapping heavy effects
}
