import 'package:flutter/material.dart';

import '../../../../core/icons/vm_icons.dart';
import '../../models/home_room_data.dart';

class HomeRoomShortcut extends StatelessWidget {
  const HomeRoomShortcut({
    super.key,
    required this.room,
    required this.onTap,
  });

  final HomeRoomData? room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasRoom = room != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEDE3D7)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF251538).withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          hasRoom ? VMIcons.home : VMIcons.createRoom,
          color: hasRoom ? const Color(0xFF12C7B7) : const Color(0xFF251538),
          size: 24,
        ),
      ),
    );
  }
}
