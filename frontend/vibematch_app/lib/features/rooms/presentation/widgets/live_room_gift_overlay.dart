import 'package:flutter/material.dart';

import '../../modules/gift_slide/presentation/gift_slide_overlay.dart';
import '../../modules/ribbon_chat/models/ribbon_message.dart';
import '../../modules/ribbon_chat/presentation/ribbon_message_overlay.dart';
import '../../modules/video_gift/presentation/clean_video_gift_overlay.dart';
import '../controllers/live_room_gift_controller.dart';
import '../live_room_models.dart';
import 'gift_flight_bus.dart';
import 'gift_flight_overlay.dart';
import 'gift_modules/lucky_packet_room_overlay.dart';
import 'live_room_event_carousel.dart';
import 'premium_gift_broadcast_overlay.dart';
import 'room_gifts.dart';

class LiveRoomGiftOverlay extends StatefulWidget {
  const LiveRoomGiftOverlay({
    super.key,
    required this.slides,
    required this.activeComboSlide,
    this.activeLuckyPacket,
    required this.bottomPadding,
    required this.onComboTap,
    required this.onComboButtonTap,
    required this.onVideoGiftFinished,
    this.onLuckyPacketGetTap,
    this.onLuckyPacketResultsDismiss,
  });

  final List<GiftSlide> slides;
  final GiftSlide? activeComboSlide;
  final LuckyPacketRoomEvent? activeLuckyPacket;
  final double bottomPadding;
  final ValueChanged<GiftSlide> onComboTap;
  final VoidCallback onComboButtonTap;
  final ValueChanged<GiftSlide> onVideoGiftFinished;
  final VoidCallback? onLuckyPacketGetTap;
  final VoidCallback? onLuckyPacketResultsDismiss;

  @override
  State<LiveRoomGiftOverlay> createState() => _LiveRoomGiftOverlayState();
}

class _LiveRoomGiftOverlayState extends State<LiveRoomGiftOverlay> {
  final List<RibbonMessage> _ribbonMessages = <RibbonMessage>[];

  @override
  Widget build(BuildContext context) {
    final normalSlides = widget.slides.where((slide) => !slide.isVideoGift).toList(growable: false);
    final hasActiveVideoGift = widget.slides.any((slide) => slide.videoAssetPath?.trim().isNotEmpty ?? false);
    final hasLuckyPacketDialog = widget.activeLuckyPacket != null && widget.activeLuckyPacket!.phase != LuckyPacketPhase.countdown;

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          const PremiumGiftBroadcastOverlay(),
          GiftSlideOverlay(
            slides: normalSlides,
            onComboTap: widget.onComboTap,
          ),
          CleanVideoGiftOverlay(
            slides: widget.slides,
            onVideoFinished: widget.onVideoGiftFinished,
          ),
          ValueListenableBuilder<GiftFlightEvent?>(
            valueListenable: GiftFlightBus.latest,
            builder: (context, event, _) {
              return GiftFlightOverlay(
                event: event,
                onCompleted: GiftFlightBus.clear,
              );
            },
          ),
          RibbonMessageOverlay(messages: _ribbonMessages),
          if (!hasActiveVideoGift && !hasLuckyPacketDialog)
            Positioned(
              right: 24,
              bottom: 104 + widget.bottomPadding,
              child: const LiveRoomEventCarousel(),
            ),
          Positioned(
            right: 18,
            bottom: 178 + widget.bottomPadding,
            child: ComboBuzzer(
              slide: widget.activeComboSlide,
              onTap: widget.onComboButtonTap,
            ),
          ),
          LuckyPacketRoomOverlay(
            packet: widget.activeLuckyPacket,
            onGetTap: widget.onLuckyPacketGetTap ?? () {},
            onDismissResults: widget.onLuckyPacketResultsDismiss ?? () {},
          ),
        ],
      ),
    );
  }
}
