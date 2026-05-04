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
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onMyRoomTap,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEDE3D7)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF251538).withValues(alpha: 0.035),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                hasRoom ? Icons.home_rounded : Icons.add_home_work_rounded,
                color: hasRoom ? const Color(0xFF12C7B7) : const Color(0xFF4A2A63),
                size: 18,
              ),
            ),
          ),
          const Spacer(),
          HomeHeaderButton(icon: Icons.search_rounded, onTap: onSearchTap),
          const SizedBox(width: 7),
          HomeHeaderButton(icon: Icons.notifications_rounded, onTap: onNotificationsTap),
        ],
      ),
    );
  }
}
