import 'package:flutter/material.dart';

import 'room_theme.dart';

class LiveRoomMinimizedBubble extends StatelessWidget {
  const LiveRoomMinimizedBubble({
    super.key,
    required this.offset,
    required this.onRestore,
    required this.onDrag,
  });

  final Offset offset;
  final VoidCallback onRestore;
  final ValueChanged<DragUpdateDetails> onDrag;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: GestureDetector(
        onTap: onRestore,
        onPanUpdate: onDrag,
        child: Container(
          width: 78,
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(colors: [RoomColors.aqua, RoomColors.violet]),
            boxShadow: [
              BoxShadow(
                color: RoomColors.aqua.withValues(alpha: 0.3),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 24),
              SizedBox(width: 5),
              Text(
                'Live',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
