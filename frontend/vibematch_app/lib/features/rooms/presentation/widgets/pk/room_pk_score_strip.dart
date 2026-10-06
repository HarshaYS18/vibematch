import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/room_pk_controller.dart';
import '../room_theme.dart';

class RoomPkScoreStrip extends StatefulWidget {
  const RoomPkScoreStrip({
    super.key,
    required this.controller,
  });

  final RoomPkController controller;

  @override
  State<RoomPkScoreStrip> createState() => _RoomPkScoreStripState();
}

class _RoomPkScoreStripState extends State<RoomPkScoreStrip> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.controller.active) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _remaining {
    final endsAt = widget.controller.match?.endsAt;
    if (endsAt == null) return '--:--';
    final delta = endsAt.difference(DateTime.now().toUtc());
    final seconds = delta.inSeconds.clamp(0, 99 * 60 + 59);
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final opponent = widget.controller.opponentRoom;
        if (!widget.controller.active || opponent == null) {
          return const SizedBox.shrink();
        }

        return Semantics(
          label:
              'PK battle. Your room ${widget.controller.localScore} points. '
              '${opponent.roomName} ${widget.controller.opponentScore} points. '
              '$_remaining remaining.',
          child: Container(
            margin: const EdgeInsets.fromLTRB(2, 0, 2, 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: RoomColors.plum.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.flash_on_rounded,
                  size: 17,
                  color: RoomColors.coral,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'FunKey  ${widget.controller.localScore}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _remaining,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      fontFeatures: <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.controller.opponentScore}  ${opponent.roomName}',
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.bolt_rounded,
                  size: 17,
                  color: RoomColors.aqua,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
