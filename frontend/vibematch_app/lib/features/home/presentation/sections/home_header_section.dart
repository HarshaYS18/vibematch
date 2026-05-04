import 'package:flutter/material.dart';

import '../../models/home_room.dart';
import '../widgets/home_common_widgets.dart';

class HomeHeaderSection extends StatelessWidget {
  const HomeHeaderSection({
    super.key,
    required this.myCreatedRoom,
    required this.onMyRoomTap,
    required this.onSearchTap,
    required this.onNotificationsTap,
  });

  final HomeRoom? myCreatedRoom;
  final VoidCallback onMyRoomTap;
  final VoidCallback onSearchTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final hasRoom = myCreatedRoom != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: onMyRoomTap,
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
                hasRoom ? Icons.home_rounded : Icons.add_home_work_rounded,
                color: hasRoom ? const Color(0xFF12C7B7) : const Color(0xFF251538),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasRoom ? myCreatedRoom!.name : 'Create your room',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
          ),
          HomeHeaderButton(icon: Icons.search_rounded, onTap: onSearchTap),
          const SizedBox(width: 8),
          HomeHeaderButton(icon: Icons.notifications_rounded, onTap: onNotificationsTap),
        ],
      ),
    );
  }
}
