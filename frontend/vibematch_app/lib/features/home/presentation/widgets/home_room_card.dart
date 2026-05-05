import 'package:flutter/material.dart';

import '../../../../core/icons/vm_icons.dart';
import '../../models/home_room.dart';

class HomeRoomCard extends StatelessWidget {
  const HomeRoomCard({
    super.key,
    required this.room,
    required this.rank,
    required this.onTap,
  });

  final HomeRoom room;
  final int rank;
  final VoidCallback onTap;

  Color get _modeColor {
    final mode = room.mode.toLowerCase();
    if (mode.contains('secret')) return const Color(0xFF8C5CF6);
    if (mode.contains('lock')) return const Color(0xFFC99A3B);
    if (mode.contains('member')) return const Color(0xFFE84C72);
    if (mode.contains('sync')) return const Color(0xFF12C7B7);
    return const Color(0xFF12C7B7);
  }

  IconData get _modeIcon {
    final mode = room.mode.toLowerCase();
    if (mode.contains('secret')) return VMIcons.secret;
    if (mode.contains('lock')) return VMIcons.lock;
    if (mode.contains('member')) return VMIcons.vip;
    if (mode.contains('sync')) return VMIcons.audioWave;
    return VMIcons.publicRoom;
  }

  @override
  Widget build(BuildContext context) {
    final friendsText = room.followedFriendsInside.isEmpty
        ? 'No followed friends inside'
        : '${room.followedFriendsInside.join(', ')} inside';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFEDE3D7)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF251538).withValues(alpha: 0.045),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _HomeRoomAvatar(room: room, size: 66),
                Positioned(
                  left: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF251538),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      '#$rank',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF251538), fontSize: 15.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: _modeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_modeIcon, color: _modeColor, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              room.mode,
                              style: TextStyle(color: _modeColor, fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    room.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _HomeRoomMiniPill(icon: VMIcons.language, text: room.language),
                      _HomeRoomMiniPill(icon: VMIcons.people, text: '${room.onlineCount}'),
                      _HomeRoomMiniPill(icon: VMIcons.fire, text: '${room.trendingScore}'),
                      _HomeRoomMiniPill(icon: VMIcons.category, text: room.type),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          friendsText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF4A2A63), fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(VMIcons.chevronRight, color: Color(0xFF7B6A86)),
                    ],
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

class _HomeRoomAvatar extends StatelessWidget {
  const _HomeRoomAvatar({required this.room, required this.size});

  final HomeRoom room;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mode = room.mode.toLowerCase();
    List<Color> colors = const [Color(0xFF12C7B7), Color(0xFF8C5CF6)];

    if (mode.contains('secret')) {
      colors = const [Color(0xFF251538), Color(0xFF8C5CF6)];
    } else if (mode.contains('lock')) {
      colors = const [Color(0xFFC99A3B), Color(0xFF4A2A63)];
    } else if (mode.contains('sync')) {
      colors = const [Color(0xFF12C7B7), Color(0xFFE84C72)];
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.34),
        gradient: LinearGradient(colors: colors),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.23),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        room.type == 'Gaming'
            ? VMIcons.games
            : room.type == 'PK'
                ? VMIcons.bolt
                : room.type == 'Music'
                    ? VMIcons.music
                    : VMIcons.audioWave,
        color: Colors.white,
        size: size * 0.42,
      ),
    );
  }
}

class _HomeRoomMiniPill extends StatelessWidget {
  const _HomeRoomMiniPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFEDE3D7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF7B6A86), size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Color(0xFF4A2A63), fontSize: 10.5, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
