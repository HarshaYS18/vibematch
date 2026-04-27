import 'package:flutter/material.dart';

import '../../main_shell/presentation/main_shell_widgets.dart';

class CreateRoomPage extends StatelessWidget {
  const CreateRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabScaffold(
      title: 'Create Room',
      subtitle: 'Start a live audio room, game room, or VibeSync room',
      child: Column(
        children: [
          PlaceholderCard(
            icon: Icons.mic_rounded,
            title: 'Audio Room',
            description:
                'Create normal 4-seat, 5-seat, 10-seat, 15-seat, or 20-seat rooms.',
          ),
          SizedBox(height: 12),
          PlaceholderCard(
            icon: Icons.favorite_rounded,
            title: 'VibeSync Room',
            description: 'Create Pulse Match or Mic Chemistry rooms later.',
          ),
          SizedBox(height: 12),
          PlaceholderCard(
            icon: Icons.lock_rounded,
            title: 'Locked / Secret Vibe',
            description:
                'Locked room and Secret Vibe room controls will connect here.',
          ),
          SizedBox(height: 12),
          PlaceholderCard(
            icon: Icons.wallpaper_rounded,
            title: 'Room Background Themes',
            description:
                'Static, dynamic, and approved custom room backgrounds will connect here.',
          ),
        ],
      ),
    );
  }
}