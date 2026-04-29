import 'package:flutter/material.dart';

class LiveRoomRibbonChatModule extends StatelessWidget {
  const LiveRoomRibbonChatModule({
    super.key,
    required this.enabled,
    required this.coinCost,
    required this.onToggleMode,
    required this.onSendRibbon,
  });

  final bool enabled;
  final int coinCost;
  final VoidCallback onToggleMode;
  final VoidCallback onSendRibbon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFE84C72).withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: enabled ? const Color(0xFFE84C72).withValues(alpha: 0.36) : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onToggleMode,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_motion_rounded,
                      color: enabled ? const Color(0xFFFFC857) : Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      enabled ? 'Floating Text' : 'Normal Text',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (enabled) ...[
              const SizedBox(width: 8),
              Text(
                '$coinCost coins',
                style: const TextStyle(
                  color: Color(0xFFFFC857),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onSendRibbon,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 15),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
