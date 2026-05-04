import 'package:flutter/material.dart';

import '../../controllers/live_room_gift_controller.dart';
import '../economy/gold_coin_icon.dart';
import '../room_theme.dart';

class LuckyPacketRoomOverlay extends StatelessWidget {
  const LuckyPacketRoomOverlay({
    super.key,
    required this.packet,
    required this.onGetTap,
    required this.onDismissResults,
  });

  final LuckyPacketRoomEvent? packet;
  final VoidCallback onGetTap;
  final VoidCallback onDismissResults;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LuckyPacketRoomEvent?>(
      valueListenable: LuckyPacketRoomBus.packet,
      builder: (context, busPacket, child) {
        final activePacket = packet ?? busPacket;
        if (activePacket == null) return const SizedBox.shrink();

        return Positioned.fill(
          child: IgnorePointer(
            ignoring: activePacket.phase == LuckyPacketPhase.countdown,
            child: Stack(
              children: [
                if (activePacket.phase != LuckyPacketPhase.countdown)
                  Positioned.fill(
                    child: Container(color: Colors.black.withValues(alpha: 0.34)),
                  ),
                if (activePacket.phase == LuckyPacketPhase.countdown)
                  Positioned(
                    top: 118,
                    right: 16,
                    child: _LuckyPacketTimerPill(packet: activePacket),
                  )
                else
                  Center(
                    child: _LuckyPacketDialog(
                      packet: activePacket,
                      onGetTap: onGetTap == _noop ? LuckyPacketRoomBus.claim : onGetTap,
                      onDismissResults: onDismissResults == _noop ? LuckyPacketRoomBus.dismissResults : onDismissResults,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _noop() {}
}

class _LuckyPacketTimerPill extends StatelessWidget {
  const _LuckyPacketTimerPill({required this.packet});

  final LuckyPacketRoomEvent packet;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFFFFD166), Color(0xFFE84C72)]),
              border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
              boxShadow: [BoxShadow(color: RoomColors.coral.withValues(alpha: 0.36), blurRadius: 18, offset: const Offset(0, 8))],
            ),
            child: const Text('🧧', style: TextStyle(fontSize: 27)),
          ),
          Positioned(
            right: -1,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: const Color(0xFF12101D),
                border: Border.all(color: RoomColors.gold.withValues(alpha: 0.55)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Text('${packet.remainingSeconds}s', style: const TextStyle(color: RoomColors.gold, fontSize: 10.5, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LuckyPacketDialog extends StatelessWidget {
  const _LuckyPacketDialog({
    required this.packet,
    required this.onGetTap,
    required this.onDismissResults,
  });

  final LuckyPacketRoomEvent packet;
  final VoidCallback onGetTap;
  final VoidCallback onDismissResults;

  @override
  Widget build(BuildContext context) {
    final isClaim = packet.phase == LuckyPacketPhase.claim;
    final isResults = packet.phase == LuckyPacketPhase.results;

    return Container(
      width: MediaQuery.sizeOf(context).width * 0.82,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF35162B), Color(0xFF17111F), Color(0xFF2A1334)],
        ),
        border: Border.all(color: RoomColors.gold.withValues(alpha: 0.30)),
        boxShadow: [BoxShadow(color: RoomColors.coral.withValues(alpha: 0.36), blurRadius: 30, offset: const Offset(0, 16))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(packet.senderName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            packet.message.trim().isEmpty ? 'sent a Lucky Packet' : packet.message.trim(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.66), fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: isResults || packet.claimedByCurrentUser ? 150 : 132,
            height: isResults || packet.claimedByCurrentUser ? 126 : 150,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: packet.claimedByCurrentUser || isResults
                    ? const [Color(0xFFFFE1A3), Color(0xFFFFA84D), Color(0xFFB34A28)]
                    : const [Color(0xFFE84C72), Color(0xFF9A2248), Color(0xFF50192D)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
              boxShadow: [BoxShadow(color: RoomColors.gold.withValues(alpha: 0.26), blurRadius: 22, offset: const Offset(0, 10))],
            ),
            child: packet.claimedByCurrentUser || isResults
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('OPEN', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const GoldCoinIcon(size: 22),
                          const SizedBox(width: 6),
                          Text('${packet.currentUserReward ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('received', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800)),
                    ],
                  )
                : const Text('🧧', style: TextStyle(fontSize: 58)),
          ),
          const SizedBox(height: 14),
          if (isClaim && !packet.claimedByCurrentUser)
            GestureDetector(
              onTap: onGetTap,
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(colors: [RoomColors.gold, RoomColors.coral]),
                ),
                child: Text('Get • ${packet.remainingSeconds}s', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
              ),
            )
          else if (isClaim)
            Text('Claim closes in ${packet.remainingSeconds}s', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800))
          else if (isResults) ...[
            _LuckyPacketResults(packet: packet),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onDismissResults,
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withValues(alpha: 0.10),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text('Close', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LuckyPacketResults extends StatelessWidget {
  const _LuckyPacketResults({required this.packet});

  final LuckyPacketRoomEvent packet;

  @override
  Widget build(BuildContext context) {
    final entries = packet.distributions.entries.toList(growable: false);
    if (entries.isEmpty) {
      return const Text('No claims this round', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800));
    }

    return Column(
      children: entries.take(5).map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            children: [
              Expanded(child: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
              const GoldCoinIcon(size: 12),
              const SizedBox(width: 4),
              Text('${entry.value}', style: const TextStyle(color: RoomColors.gold, fontSize: 11, fontWeight: FontWeight.w900)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
