import 'package:flutter/material.dart';

import '../../../core/navigation/vm_navigator.dart';
import '../data/profile_rooms_repository.dart';

class ProfileRoomsPage extends StatelessWidget {
  const ProfileRoomsPage({
    super.key,
    required this.userId,
    this.publicUserId,
  });

  final int userId;
  final int? publicUserId;

  @override
  Widget build(BuildContext context) {
    final rooms = const ProfileRoomsRepository().loadMyRooms(
      userId: userId,
      publicUserId: publicUserId,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  _RoundButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Rooms',
                          style: TextStyle(
                            color: Color(0xFF251538),
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Owner, admin and member rooms',
                          style: TextStyle(
                            color: const Color(0xFF7B6A86).withValues(alpha: 0.92),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CountPill(count: rooms.length),
                ],
              ),
            ),
            Expanded(
              child: rooms.isEmpty
                  ? const _EmptyRooms()
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                      itemCount: rooms.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        return _RoomCard(
                          room: room,
                          onTap: () => VmNavigator.openLiveRoom(
                            context,
                            roomName: room.roomName,
                            roomId: room.roomId,
                            language: room.language,
                            modeTitle: room.modeTitle,
                            onlineCount: room.onlineCount,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.onTap});

  final ProfileRoomRecord room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFECE2D8)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF251538).withValues(alpha: 0.045),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(19),
                  gradient: _roleGradient(room.role),
                ),
                child: Icon(_roleIcon(room.role), color: Colors.white, size: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            room.roomName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF251538), fontSize: 15.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (room.isLive) const _LiveDot(),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${room.roomId} â€¢ ${room.language} â€¢ ${room.modeTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      children: [
                        _MiniPill(label: room.roleLabel, icon: Icons.verified_user_rounded),
                        _MiniPill(label: '${room.onlineCount} online', icon: Icons.graphic_eq_rounded),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFB8A8BD)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6D5DF6)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Color(0xFF251538), fontSize: 10.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE84C72).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Color(0xFFE84C72), size: 7),
          SizedBox(width: 4),
          Text('LIVE', style: TextStyle(color: Color(0xFFE84C72), fontSize: 9.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF6D5DF6).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF6D5DF6).withValues(alpha: 0.18)),
      ),
      child: Text(
        '$count',
        style: const TextStyle(color: Color(0xFF6D5DF6), fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: Icon(icon, color: const Color(0xFF251538), size: 20),
      ),
    );
  }
}

class _EmptyRooms extends StatelessWidget {
  const _EmptyRooms();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.meeting_room_rounded, color: Color(0xFF6D5DF6), size: 42),
            SizedBox(height: 10),
            Text('No rooms yet', style: TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900)),
            SizedBox(height: 5),
            Text(
              'Rooms where you are owner, admin, or member will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

LinearGradient _roleGradient(ProfileRoomRole role) {
  switch (role) {
    case ProfileRoomRole.owner:
      return const LinearGradient(colors: [Color(0xFFFFD36A), Color(0xFFC99A3B)]);
    case ProfileRoomRole.admin:
      return const LinearGradient(colors: [Color(0xFF6D5DF6), Color(0xFF8C5CF6)]);
    case ProfileRoomRole.member:
      return const LinearGradient(colors: [Color(0xFF12C7B7), Color(0xFF0BA99B)]);
  }
}

IconData _roleIcon(ProfileRoomRole role) {
  switch (role) {
    case ProfileRoomRole.owner:
      return Icons.workspace_premium_rounded;
    case ProfileRoomRole.admin:
      return Icons.admin_panel_settings_rounded;
    case ProfileRoomRole.member:
      return Icons.group_rounded;
  }
}
