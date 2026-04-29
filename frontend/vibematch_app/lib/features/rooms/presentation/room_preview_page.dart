import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';

class RoomPreviewPage extends StatelessWidget {
  const RoomPreviewPage({
    super.key,
    this.roomName = 'Vibe Room',
    this.roomId = 'VM000000',
    this.language = 'English',
    this.modeTitle = 'Open',
    this.onlineCount = 0,
  });

  final String roomName;
  final String roomId;
  final String language;
  final String modeTitle;
  final int onlineCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F1),
        foregroundColor: const Color(0xFF251538),
        elevation: 0,
        title: const Text(
          'Room Preview',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF251538),
                    Color(0xFF4A2A63),
                    Color(0xFF12C7B7),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF251538).withValues(alpha: 0.16),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 44),
                  const SizedBox(height: 18),
                  Text(
                    roomName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ID $roomId · $language · $modeTitle · $onlineCount online',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          VmRoutes.liveRoom,
                          arguments: LiveRoomRouteArgs(
                            roomName: roomName,
                            roomId: roomId,
                            language: language,
                            modeTitle: modeTitle,
                            onlineCount: onlineCount,
                          ),
                        );
                      },
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Enter Room'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
