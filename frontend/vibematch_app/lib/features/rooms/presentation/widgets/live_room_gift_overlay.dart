import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'live_room_event_carousel.dart';
import 'room_gifts.dart';

class LiveRoomGiftOverlay extends StatelessWidget {
  const LiveRoomGiftOverlay({
    super.key,
    required this.slides,
    required this.activeComboSlide,
    required this.bottomPadding,
    required this.onComboTap,
    required this.onComboButtonTap,
  });

  final List<GiftSlide> slides;
  final GiftSlide? activeComboSlide;
  final double bottomPadding;
  final ValueChanged<GiftSlide> onComboTap;
  final VoidCallback onComboButtonTap;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Stack(
      children: [
        Positioned(
          left: 12,
          top: size.height * 0.50,
          child: GiftSlideStack(
            slides: slides,
            onComboTap: onComboTap,
          ),
        ),
        Positioned(
          right: 27,
          bottom: 140 + bottomPadding,
          child: const LiveRoomEventCarousel(),
        ),
        Positioned(
          right: 18,
          bottom: 52 + bottomPadding,
          child: ComboBuzzer(
            slide: activeComboSlide,
            onTap: onComboButtonTap,
          ),
        ),
      ],
    );
  }
}
