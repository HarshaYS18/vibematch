import 'package:flutter/material.dart';

import '../../modules/gift_slide/presentation/gift_slide_overlay.dart';
import '../../modules/ribbon_chat/models/ribbon_message.dart';
import '../../modules/ribbon_chat/presentation/ribbon_message_overlay.dart';
import '../../modules/video_gift/presentation/video_gift_overlay.dart';
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
    required this.onVideoGiftFinished,
  });

  final List<GiftSlide> slides;
  final GiftSlide? activeComboSlide;
  final double bottomPadding;
  final ValueChanged<GiftSlide> onComboTap;
  final VoidCallback onComboButtonTap;
  final ValueChanged<GiftSlide> onVideoGiftFinished;

  @override
  State<LiveRoomGiftOverlay> createState() => _LiveRoomGiftOverlayState();
}

class _LiveRoomGiftOverlayState extends State<LiveRoomGiftOverlay> {
  final List<RibbonMessage> _ribbonMessages = <RibbonMessage>[];

  @override
  Widget build(BuildContext context) {
    final normalSlides = widget.slides.where((slide) => !slide.isVideoGift).toList(growable: false);
    final hasActiveVideoGift = widget.slides.any((slide) => slide.videoAssetPath?.trim().isNotEmpty ?? false);

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          GiftSlideOverlay(
            slides: normalSlides,
            onComboTap: widget.onComboTap,
          ),
          VideoGiftOverlay(
            slides: widget.slides,
            onVideoFinished: widget.onVideoGiftFinished,
          ),
          RibbonMessageOverlay(messages: _ribbonMessages),
          if (!hasActiveVideoGift)
            Positioned(
              left: 16,
              bottom: 104 + widget.bottomPadding,
              child: const LiveRoomEventCarousel(),
            ),
          Positioned(
            left: 18,
            bottom: 178 + widget.bottomPadding,
            child: ComboBuzzer(
              slide: widget.activeComboSlide,
              onTap: widget.onComboButtonTap,
            ),
          ),
        ],
      ),
    );
  }
}
