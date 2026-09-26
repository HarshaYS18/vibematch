import 'package:flutter/material.dart';

import '../../experience/presentation/experience_detail_page.dart';
import '../../rooms/data/live_room_media_signaling_service.dart';

/// Room EXP details for an explicitly scoped room.
///
/// [roomPublicId] should be supplied by room-scoped navigation. The attached
/// media room is only a transient routing fallback and is never durable room
/// state authority.
class RoomLevelPage extends StatelessWidget {
  const RoomLevelPage({super.key, this.roomPublicId});

  final String? roomPublicId;

  @override
  Widget build(BuildContext context) {
    final activeRoomId =
        (roomPublicId ?? LiveRoomMediaSignalingService.instance.roomId)?.trim();

    if (activeRoomId == null || activeRoomId.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF7F1),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFAF7F1),
          foregroundColor: const Color(0xFF251538),
          elevation: 0,
          title: const Text(
            'Room Lv',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Room EXP details will load after the active room opens.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF7B6A86),
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
    }

    return ExperienceDetailPage(
      args: ExperienceDetailRouteArgs(
        kind: ExperienceDetailKind.room,
        roomPublicId: activeRoomId,
        title: 'Room Lv',
      ),
    );
  }
}
