import 'package:flutter/material.dart';

class InboxV3LockedPullReveal extends StatelessWidget {
  const InboxV3LockedPullReveal({
    super.key,
    required this.extent,
    required this.lockedCount,
    this.triggerExtent = 72,
  });

  final double extent;
  final int lockedCount;
  final double triggerExtent;

  @override
  Widget build(BuildContext context) {
    final progress = (extent / triggerExtent).clamp(0.0, 1.0);
    final ready = progress >= 1.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      height: extent,
      alignment: Alignment.bottomCenter,
      child: IgnorePointer(
        child: Opacity(
          opacity: progress,
          child: Transform.scale(
            scale: 0.96 + (progress * 0.04),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF111114),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12 * progress),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: ready ? const Color(0xFF22C55E) : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      ready ? Icons.lock_open_rounded : Icons.lock_rounded,
                      color: ready ? Colors.white : const Color(0xFF111114),
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ready ? 'Release to open locked chats' : 'Keep pulling for locked chats',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  if (lockedCount > 0)
                    Text(
                      '$lockedCount',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
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
