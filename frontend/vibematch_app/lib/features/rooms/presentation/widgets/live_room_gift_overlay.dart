import 'package:flutter/material.dart';

import '../../modules/gift_slide/presentation/gift_slide_overlay.dart';
import '../../modules/ribbon_chat/models/ribbon_message.dart';
import '../../modules/ribbon_chat/presentation/ribbon_message_overlay.dart';
import '../live_room_models.dart';
import 'live_room_event_carousel.dart';
import 'room_gifts.dart';

class LiveRoomGiftOverlay extends StatefulWidget {
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
  State<LiveRoomGiftOverlay> createState() => _LiveRoomGiftOverlayState();
}

class _LiveRoomGiftOverlayState extends State<LiveRoomGiftOverlay> {
  final List<RibbonMessage> _ribbonMessages = <RibbonMessage>[];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GiftSlideOverlay(
          slides: widget.slides,
          onComboTap: widget.onComboTap,
        ),
        RibbonMessageOverlay(messages: _ribbonMessages),
        Positioned(
          right: 27,
          bottom: 140 + widget.bottomPadding,
          child: const LiveRoomEventCarousel(),
        ),
        Positioned(
          right: 18,
          bottom: 52 + widget.bottomPadding,
          child: ComboBuzzer(
            slide: widget.activeComboSlide,
            onTap: widget.onComboButtonTap,
          ),
        ),
      ],
    );
  }
}
