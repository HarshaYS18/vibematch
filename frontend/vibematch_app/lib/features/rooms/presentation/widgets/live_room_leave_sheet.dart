import 'package:flutter/material.dart';

import 'room_theme.dart';

class LiveRoomLeaveSheet extends StatelessWidget {
  const LiveRoomLeaveSheet({
    super.key,
    required this.onStay,
    required this.onLeave,
  });

  final VoidCallback onStay;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          const SizedBox(height: 16),
          const Text(
            'Leave room?',
            style: TextStyle(
              color: RoomColors.plum,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Stay will minimize this chatroom into a floating bubble.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7B6A86),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onStay,
                  child: const Text('Stay'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onLeave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RoomColors.plum,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Leave'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}