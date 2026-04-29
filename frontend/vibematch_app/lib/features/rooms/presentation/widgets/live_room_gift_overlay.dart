import 'package:flutter/material.dart';

import '../../modules/gift_slide/presentation/gift_slide_overlay.dart';
import '../../modules/ribbon_chat/models/ribbon_message.dart';
import '../../modules/ribbon_chat/presentation/ribbon_message_composer_sheet.dart';
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
          right: 20,
          bottom: 98 + widget.bottomPadding,
          child: _RibbonComposerButton(onTap: _openRibbonComposer),
        ),
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

  void _openRibbonComposer() {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF160A24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => RibbonMessageComposerSheet(
        roomId: 'local-room-preview',
        senderUserId: 'local-user-preview',
        senderName: 'You',
        onSendRibbonMessage: _sendRibbonMessage,
      ),
    );
  }

  void _sendRibbonMessage(RibbonMessage message) {
    setState(() => _ribbonMessages.add(message));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Floating text sent. Backend coin deduction later.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
        backgroundColor: const Color(0xFF171024).withValues(alpha: 0.96),
      ),
    );
  }
}

class _RibbonComposerButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RibbonComposerButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD66B), Color(0xFFB765FF)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD66B).withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, color: Color(0xFF20112F), size: 17),
              SizedBox(width: 6),
              Text(
                'Floating Text',
                style: TextStyle(
                  color: Color(0xFF20112F),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
