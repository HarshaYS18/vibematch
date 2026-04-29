import 'package:flutter/material.dart';

import 'room_theme.dart';

class LiveRoomBlockedListSheet extends StatefulWidget {
  const LiveRoomBlockedListSheet({
    super.key,
    this.initialUsers = mockBlockedRoomUsers,
  });

  final List<BlockedRoomUser> initialUsers;

  @override
  State<LiveRoomBlockedListSheet> createState() => _LiveRoomBlockedListSheetState();
}

class _LiveRoomBlockedListSheetState extends State<LiveRoomBlockedListSheet> {
  late final List<BlockedRoomUser> _blockedUsers = List<BlockedRoomUser>.of(widget.initialUsers);

  int get _foreverCount => _blockedUsers.where((user) => user.isForever).length;

  void _unblockUser(BlockedRoomUser user) {
    setState(() {
      _blockedUsers.removeWhere((blockedUser) => blockedUser.id == user.id);
    });

    RoomToast.show(
      context,
      '${user.displayName} removed from this room blocked list.',
    );
  }

  void _restoreMockUsers() {
    setState(() {
      _blockedUsers
        ..clear()
        ..addAll(mockBlockedRoomUsers);
    });

    RoomToast.show(context, 'Sample blocked users restored for UI testing.');
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.72,
      padding: EdgeInsets.fromLTRB(14, 10, 14, bottomPadding + 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(width: 44),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: RoomColors.coral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.block_rounded,
                  color: RoomColors.coral,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Blocked List',
                      style: TextStyle(
                        color: RoomColors.plum,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Users restricted from re-entering this room',
                      style: TextStyle(
                        color: Color(0xFF82758E),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _ClosePill(onTap: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _BlockedStatPill(
                icon: Icons.group_off_rounded,
                label: '${_blockedUsers.length} blocked',
                color: RoomColors.plum,
              ),
              const SizedBox(width: 8),
              _BlockedStatPill(
                icon: Icons.all_inclusive_rounded,
                label: '$_foreverCount forever',
                color: RoomColors.coral,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RoomColors.gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: RoomColors.gold.withValues(alpha: 0.26)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_rounded, color: RoomColors.gold, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Backend unblock route will connect here next. For now, Unblock removes the user locally so this action is testable.',
                    style: TextStyle(
                      color: RoomColors.plum,
                      fontSize: 11.2,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _blockedUsers.isEmpty
                ? _BlockedEmptyState(onRestoreTap: _restoreMockUsers)
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _blockedUsers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final user = _blockedUsers[index];
                      return _BlockedUserTile(
                        user: user,
                        onUnblockTap: () => _unblockUser(user),
                        onDetailsTap: () => RoomToast.show(
                          context,
                          '${user.displayName} block details opened locally.',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class BlockedRoomUser {
  const BlockedRoomUser({
    required this.id,
    required this.displayName,
    required this.publicUserId,
    required this.reason,
    required this.durationLabel,
    required this.blockedBy,
    required this.blockedAtLabel,
    required this.avatarColors,
    this.isForever = false,
  });

  final String id;
  final String displayName;
  final String publicUserId;
  final String reason;
  final String durationLabel;
  final String blockedBy;
  final String blockedAtLabel;
  final List<Color> avatarColors;
  final bool isForever;

  String get avatarLetter {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }
}

const List<BlockedRoomUser> mockBlockedRoomUsers = [
  BlockedRoomUser(
    id: 'blocked_riyan',
    displayName: 'Riyan',
    publicUserId: '6418002191',
    reason: 'Spam messages in room chat',
    durationLabel: '1 Hour',
    blockedBy: 'Harsha',
    blockedAtLabel: '12 min ago',
    avatarColors: [Color(0xFFE84C72), Color(0xFFFFC857)],
  ),
  BlockedRoomUser(
    id: 'blocked_akash',
    displayName: 'Akash',
    publicUserId: '6418003314',
    reason: 'Repeated seat disturbance',
    durationLabel: '1 Day',
    blockedBy: 'Riya',
    blockedAtLabel: '1 hr ago',
    avatarColors: [Color(0xFF12C7B7), Color(0xFF7A5CFF)],
  ),
  BlockedRoomUser(
    id: 'blocked_guest_77',
    displayName: 'Guest 77',
    publicUserId: '6418007788',
    reason: 'Unsafe behavior after warning',
    durationLabel: 'Forever',
    blockedBy: 'Harsha',
    blockedAtLabel: 'Yesterday',
    avatarColors: [Color(0xFF251538), Color(0xFFE84C72)],
    isForever: true,
  ),
];

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({
    required this.user,
    required this.onUnblockTap,
    required this.onDetailsTap,
  });

  final BlockedRoomUser user;
  final VoidCallback onUnblockTap;
  final VoidCallback onDetailsTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onDetailsTap,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFFFCFAF6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8DDCF)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: user.avatarColors),
                  boxShadow: [
                    BoxShadow(
                      color: user.avatarColors.last.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    user.avatarLetter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: RoomColors.plum,
                              fontSize: 13.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _DurationBadge(user: user),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ID ${user.publicUserId} • by ${user.blockedBy} • ${user.blockedAtLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF82758E),
                        fontSize: 10.7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RoomColors.plum,
                        fontSize: 11.3,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        _MiniActionPill(
                          icon: Icons.remove_circle_outline_rounded,
                          label: 'Unblock',
                          color: RoomColors.aqua,
                          onTap: onUnblockTap,
                        ),
                        const SizedBox(width: 8),
                        _MiniActionPill(
                          icon: Icons.history_rounded,
                          label: 'Details',
                          color: RoomColors.plum,
                          onTap: onDetailsTap,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.user});

  final BlockedRoomUser user;

  @override
  Widget build(BuildContext context) {
    final color = user.isForever ? RoomColors.coral : RoomColors.gold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        user.durationLabel,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniActionPill extends StatelessWidget {
  const _MiniActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.11),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockedStatPill extends StatelessWidget {
  const _BlockedStatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosePill extends StatelessWidget {
  const _ClosePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RoomColors.plum.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: const SizedBox(
          width: 34,
          height: 34,
          child: Icon(Icons.close_rounded, color: RoomColors.plum, size: 18),
        ),
      ),
    );
  }
}

class _BlockedEmptyState extends StatelessWidget {
  const _BlockedEmptyState({required this.onRestoreTap});

  final VoidCallback onRestoreTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: RoomColors.aqua.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: RoomColors.aqua,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No blocked users',
            style: TextStyle(
              color: RoomColors.plum,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'This room has no local blocked users right now.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF82758E),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _MiniActionPill(
            icon: Icons.refresh_rounded,
            label: 'Restore sample list',
            color: RoomColors.plum,
            onTap: onRestoreTap,
          ),
        ],
      ),
    );
  }
}
