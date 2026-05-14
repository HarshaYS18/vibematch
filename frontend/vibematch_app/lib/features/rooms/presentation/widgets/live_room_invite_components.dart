import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'chat_vip_badge.dart';

class LiveRoomInviteHandle extends StatelessWidget {
  const LiveRoomInviteHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFE0D5CB),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class LiveRoomInviteHeader extends StatelessWidget {
  const LiveRoomInviteHeader({
    super.key,
    required this.seatIndex,
    required this.userCount,
  });

  final int seatIndex;
  final int userCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Invite to seat ${seatIndex + 1}',
            style: const TextStyle(
              color: Color(0xFF251538),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          '$userCount users',
          style: const TextStyle(
            color: Color(0xFF7B6A86),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class LiveRoomInviteEmptyState extends StatelessWidget {
  const LiveRoomInviteEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No users available to invite.',
        style: TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800),
      ),
    );
  }
}

class LiveRoomInviteSectionLabel extends StatelessWidget {
  const LiveRoomInviteSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF7B6A86),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class LiveRoomInviteUserRow extends StatelessWidget {
  const LiveRoomInviteUserRow({
    super.key,
    required this.user,
    required this.isOnline,
    required this.invited,
    required this.onInvite,
  });

  final SeatUser user;
  final bool isOnline;
  final bool invited;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          LiveRoomInviteAvatar(user: user, isOnline: isOnline),
          const SizedBox(width: 10),
          Expanded(child: LiveRoomInviteUserInfo(user: user)),
          TextButton(
            onPressed: invited ? null : onInvite,
            child: Text(invited ? 'Invited' : 'Invite'),
          ),
        ],
      ),
    );
  }
}

class LiveRoomInviteAvatar extends StatelessWidget {
  const LiveRoomInviteAvatar({
    super.key,
    required this.user,
    required this.isOnline,
  });

  final SeatUser user;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl?.trim();
    final fallback = Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: user.avatarColors),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        user.name.isEmpty ? '?' : user.name.characters.first.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatarUrl == null || avatarUrl.isEmpty
            ? fallback
            : ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  avatarUrl,
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => fallback,
                ),
              ),
        if (isOnline)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: const Color(0xFF12C7B7),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class LiveRoomInviteUserInfo extends StatelessWidget {
  const LiveRoomInviteUserInfo({super.key, required this.user});

  final SeatUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF251538),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 5),
            ChatVipBadge(level: user.vipLevel, showWhenZero: true),
          ],
        ),
        Text(
          user.roleLabel.isEmpty ? 'Room user' : user.roleLabel,
          style: const TextStyle(
            color: Color(0xFF7B6A86),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
