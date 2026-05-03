import 'package:flutter/material.dart';

import '../../models/home_room_data.dart';
import 'home_action_button.dart';
import 'home_room_shortcut.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.myRoom,
    required this.onMyRoomTap,
    required this.onSearchTap,
    required this.onNotificationsTap,
  });

  final HomeRoomData? myRoom;
  final VoidCallback onMyRoomTap;
  final VoidCallback onSearchTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 14),
      child: Row(
        children: [
          HomeRoomShortcut(room: myRoom, onTap: onMyRoomTap),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              myRoom == null ? 'Create your room' : myRoom!.name,
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
          HomeActionButton(icon: Icons.search_rounded, onTap: onSearchTap),
          const SizedBox(width: 8),
          HomeActionButton(
            icon: Icons.notifications_rounded,
            onTap: onNotificationsTap,
          ),
        ],
      ),
    );
  }
}
