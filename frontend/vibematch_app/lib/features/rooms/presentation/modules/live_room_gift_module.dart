import 'package:flutter/material.dart';

class LiveRoomGiftModule extends StatelessWidget {
  const LiveRoomGiftModule({
    super.key,
    required this.onOpenGiftPanel,
    required this.comboActive,
    this.comboLabel = 'Gift',
  });

  final VoidCallback onOpenGiftPanel;
  final bool comboActive;
  final String comboLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onOpenGiftPanel,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFC857), Color(0xFFE84C72)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE84C72).withValues(alpha: comboActive ? 0.42 : 0.22),
                blurRadius: comboActive ? 22 : 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
