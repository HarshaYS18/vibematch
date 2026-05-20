import 'package:flutter/material.dart';

import '../../models/inbox_call_models.dart';

class InboxCallOverlaySheet extends StatelessWidget {
  const InboxCallOverlaySheet({
    super.key,
    required this.session,
    required this.onAccept,
    required this.onDecline,
    required this.onEnd,
  });

  final InboxCallSession session;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final colors = session.isVideo
        ? const [Color(0xFF6D5DF6), Color(0xFFFF4F9A)]
        : const [Color(0xFF12C7B7), Color(0xFF6D5DF6)];
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + bottom),
        decoration: BoxDecoration(
          color: const Color(0xFF12091F),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.26), blurRadius: 34, offset: const Offset(0, 16))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: colors)),
              child: Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF251538)),
                child: Center(child: Text(session.peerAvatarText, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900))),
              ),
            ),
            const SizedBox(height: 14),
            Text(session.peerName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
            const SizedBox(height: 4),
            Text(session.title, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFCDBCE7), fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(session.statusLabel, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF2DD4BF), fontSize: 12, fontWeight: FontWeight.w900)),
            const SizedBox(height: 18),
            if (session.isIncoming && session.isRinging)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CallCircleButton(icon: Icons.call_end_rounded, color: const Color(0xFFE84C72), label: 'Decline', onTap: onDecline),
                  const SizedBox(width: 28),
                  _CallCircleButton(icon: session.isVideo ? Icons.videocam_rounded : Icons.call_rounded, color: const Color(0xFF18D17B), label: 'Accept', onTap: onAccept),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CallCircleButton(icon: Icons.call_end_rounded, color: const Color(0xFFE84C72), label: 'End', onTap: onEnd),
                ],
              ),
            const SizedBox(height: 14),
            const Text(
              'Stay here while the call connects.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9B8CA5), fontSize: 11.2, height: 1.35, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class InboxMiniCallOverlay extends StatelessWidget {
  const InboxMiniCallOverlay({super.key, required this.session, required this.onTap, required this.onEnd});

  final InboxCallSession session;
  final VoidCallback onTap;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 10,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF12091F).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.45)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF12C7B7), Color(0xFF7C3AED)])),
                  child: Center(child: Text(session.peerAvatarText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)),
                      Text(session.peerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFCDBCE7), fontSize: 11.2, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                IconButton(onPressed: onEnd, icon: const Icon(Icons.call_end_rounded, color: Color(0xFFE84C72), size: 20)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InboxCallSummaryTile extends StatelessWidget {
  const InboxCallSummaryTile({super.key, required this.summary});

  final InboxCallSummaryMessage summary;

  @override
  Widget build(BuildContext context) {
    final color = summary.status == InboxCallStatus.missed ? const Color(0xFFE84C72) : const Color(0xFF12C7B7);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8F5FF), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE2D8))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(summary.type == InboxCallType.video ? Icons.videocam_rounded : Icons.call_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Flexible(child: Text(summary.label, style: const TextStyle(color: Color(0xFF251538), fontSize: 12, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}

class _CallCircleButton extends StatelessWidget {
  const _CallCircleButton({required this.icon, required this.color, required this.label, required this.onTap});

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(width: 58, height: 58, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 25)),
        ),
        const SizedBox(height: 7),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
