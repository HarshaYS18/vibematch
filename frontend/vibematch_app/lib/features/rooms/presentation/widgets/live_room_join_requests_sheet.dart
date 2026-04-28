import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_theme.dart';

class LiveRoomJoinRequestsSheet extends StatelessWidget {
  const LiveRoomJoinRequestsSheet({
    super.key,
    required this.users,
    required this.onApprove,
    required this.onReject,
  });

  final List<SeatUser> users;
  final ValueChanged<SeatUser> onApprove;
  final ValueChanged<SeatUser> onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.58,
      ),
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(width: 42),
          const SizedBox(height: 12),
          const Text(
            'Join requests',
            style: TextStyle(
              color: RoomColors.plum,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (users.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: RoomColors.pearl,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: RoomColors.softLine),
              ),
              child: const Text(
                'No pending join requests.',
                style: TextStyle(
                  color: Color(0xFF7B6A86),
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: users.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return _JoinRequestRow(
                    user: user,
                    onApprove: () => onApprove(user),
                    onReject: () => onReject(user),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _JoinRequestRow extends StatelessWidget {
  const _JoinRequestRow({
    required this.user,
    required this.onApprove,
    required this.onReject,
  });

  final SeatUser user;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: RoomColors.pearl,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RoomColors.softLine),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: user.avatarColors),
            ),
            child: Text(
              avatarLetter(user.name),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RoomColors.plum,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  user.roleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF7B6A86),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onReject,
            style: TextButton.styleFrom(
              foregroundColor: RoomColors.coral,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
            child: const Text('Reject'),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onApprove,
            style: TextButton.styleFrom(
              foregroundColor: RoomColors.aqua,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }
}