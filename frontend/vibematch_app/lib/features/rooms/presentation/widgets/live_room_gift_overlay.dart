import 'package:flutter/material.dart';

import '../../modules/ribbon_chat/models/ribbon_message.dart';
import '../../modules/ribbon_chat/presentation/ribbon_message_composer_sheet.dart';
import '../../modules/ribbon_chat/presentation/ribbon_message_overlay.dart';
import '../live_room_models.dart';
import 'live_room_event_carousel.dart';
import 'room_gifts.dart';
import 'room_theme.dart';

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
    final size = MediaQuery.sizeOf(context);

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: size.height * 0.42,
          child: _CenteredGiftSlideStack(
            slides: widget.slides,
            onComboTap: widget.onComboTap,
          ),
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

class _CenteredGiftSlideStack extends StatelessWidget {
  const _CenteredGiftSlideStack({
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
          child: _CenteredGiftSlideCard(
            slide: slide,
            onComboTap: () => onComboTap(slide),
          ),
        );
      }).toList(),
    );
  }
}

class _CenteredGiftSlideCard extends StatelessWidget {
  const _CenteredGiftSlideCard({
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
