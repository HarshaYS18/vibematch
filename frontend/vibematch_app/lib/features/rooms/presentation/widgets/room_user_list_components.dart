import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'chat_vip_badge.dart';
import 'room_theme.dart';

class RoomUserListHeader extends StatelessWidget {
  const RoomUserListHeader({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Users in room ($count)',
      style: const TextStyle(
        color: RoomColors.plum,
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class RoomUserListCard extends StatelessWidget {
  const RoomUserListCard({
    super.key,
    required this.user,
    required this.onTap,
  });

  final SeatUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F5FB),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          child: Row(
            children: [
              RoomUserListAvatar(user: user, onTap: onTap),
              const SizedBox(width: 12),
              Expanded(child: RoomUserListIdentity(user: user)),
              RoomUserListVipPill(vipLevel: user.vipLevel),
            ],
          ),
        ),
      ),
    );
  }
}

class RoomUserListAvatar extends StatelessWidget {
  const RoomUserListAvatar({
    super.key,
    required this.user,
    required this.onTap,
  });

  final SeatUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: user.avatarColors),
        ),
        alignment: Alignment.center,
        child: Text(
          avatarLetter(user.name),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class RoomUserListIdentity extends StatelessWidget {
  const RoomUserListIdentity({super.key, required this.user});

  final SeatUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: RoomColors.plum,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.roleLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF7B6A86),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class RoomUserListVipPill extends StatelessWidget {
  const RoomUserListVipPill({super.key, required this.vipLevel});

  final int vipLevel;

  @override
  Widget build(BuildContext context) {
    return ChatVipBadge(level: vipLevel, showWhenZero: true);
  }
}
