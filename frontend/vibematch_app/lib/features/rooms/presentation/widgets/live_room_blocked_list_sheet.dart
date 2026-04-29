import 'package:flutter/material.dart';

import '../../data/room_moderation_repository.dart';
import 'room_theme.dart';

class LiveRoomBlockedListSheet extends StatefulWidget {
  const LiveRoomBlockedListSheet({
    super.key,
    required this.roomId,
    this.repository,
    this.initialUsers = const <BlockedRoomUser>[],
  });

  final String roomId;
  final RoomModerationRepository? repository;
  final List<BlockedRoomUser> initialUsers;

  @override
  State<LiveRoomBlockedListSheet> createState() => _LiveRoomBlockedListSheetState();
}

class _LiveRoomBlockedListSheetState extends State<LiveRoomBlockedListSheet> {
  late final RoomModerationRepository _repository = widget.repository ?? RoomModerationRepository();
  late final bool _ownsRepository = widget.repository == null;
  late final List<BlockedRoomUser> _blockedUsers = List<BlockedRoomUser>.of(widget.initialUsers);

  bool _loading = true;
  bool _usingLocalFallback = false;
  bool _unblockInProgress = false;

  int get _foreverCount => _blockedUsers.where((user) => user.isForever).length;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  @override
  void dispose() {
    if (_ownsRepository) _repository.close();
    super.dispose();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() {
      _loading = true;
      _usingLocalFallback = false;
    });

    try {
      final blockedUsers = await _repository.listBlockedUsers(roomId: widget.roomId);
      if (!mounted) return;

      setState(() {
        _blockedUsers
          ..clear()
          ..addAll(blockedUsers.map(BlockedRoomUser.fromDto));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _blockedUsers
          ..clear()
          ..addAll(widget.initialUsers.isNotEmpty ? widget.initialUsers : mockBlockedRoomUsers);
        _loading = false;
        _usingLocalFallback = true;
      });

      RoomToast.show(context, 'Blocked list loaded locally. Backend connection failed.');
    }
  }

  Future<void> _unblockUser(BlockedRoomUser user) async {
    if (_unblockInProgress) return;

    if (user.kickoutId == null || _usingLocalFallback) {
      _removeUserLocally(user);
      RoomToast.show(context, '${user.displayName} removed locally from blocked list.');
      return;
    }

    setState(() => _unblockInProgress = true);

    try {
      await _repository.unblockUser(
        roomId: widget.roomId,
        kickoutId: user.kickoutId!,
      );

      if (!mounted) return;
      _removeUserLocally(user);
      RoomToast.show(context, '${user.displayName} removed from this room blocked list.');
    } catch (_) {
      if (!mounted) return;
      RoomToast.show(context, 'Unblock failed. Check backend connection and permissions.');
    } finally {
      if (mounted) setState(() => _unblockInProgress = false);
    }
  }

  void _removeUserLocally(BlockedRoomUser user) {
    setState(() {
      _blockedUsers.removeWhere((blockedUser) => blockedUser.id == user.id);
    });
  }

  void _restoreMockUsers() {
    setState(() {
      _blockedUsers
        ..clear()
        ..addAll(mockBlockedRoomUsers);
      _usingLocalFallback = true;
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
          _BlockedNotice(
            usingLocalFallback: _usingLocalFallback,
            onRetry: _loadBlockedUsers,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: RoomColors.aqua),
                  )
                : _blockedUsers.isEmpty
                    ? _BlockedEmptyState(
                        usingLocalFallback: _usingLocalFallback,
                        onRestoreTap: _restoreMockUsers,
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _blockedUsers.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 9),
                        itemBuilder: (context, index) {
                          final user = _blockedUsers[index];
                          return _BlockedUserTile(
                            user: user,
                            busy: _unblockInProgress,
                            onUnblockTap: () => _unblockUser(user),
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
    required this.durationLabel,
    required this.blockedBy,
    required this.blockedAtLabel,
    required this.avatarColors,
    this.kickoutId,
    this.isForever = false,
  });

  final String id;
  final String displayName;
  final String publicUserId;
  final String durationLabel;
  final String blockedBy;
  final String blockedAtLabel;
  final List<Color> avatarColors;
  final int? kickoutId;
  final bool isForever;

  factory BlockedRoomUser.fromDto(RoomBlockedUserDto dto) {
    return BlockedRoomUser(
      id: 'kickout_${dto.id}',
      kickoutId: dto.id,
      displayName: dto.displayName,
      publicUserId: dto.publicUserIdLabel,
      durationLabel: dto.durationLabel,
      blockedBy: dto.blockedByLabel,
      blockedAtLabel: dto.blockedAtLabel,
      isForever: dto.isForever,
      avatarColors: _avatarColorsForSeed(dto.id),
    );
  }

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
    durationLabel: '1 Hour',
    blockedBy: 'Harsha',
    blockedAtLabel: '12 min ago',
    avatarColors: [Color(0xFFE84C72), Color(0xFFFFC857)],
  ),
  BlockedRoomUser(
    id: 'blocked_akash',
    displayName: 'Akash',
    publicUserId: '6418003314',
    durationLabel: '1 Day',
    blockedBy: 'Riya',
    blockedAtLabel: '1 hr ago',
    avatarColors: [Color(0xFF12C7B7), Color(0xFF7A5CFF)],
  ),
  BlockedRoomUser(
    id: 'blocked_guest_77',
    displayName: 'Guest 77',
    publicUserId: '6418007788',
    durationLabel: 'Forever',
    blockedBy: 'Harsha',
    blockedAtLabel: 'Yesterday',
    avatarColors: [Color(0xFF251538), Color(0xFFE84C72)],
    isForever: true,
  ),
];

List<Color> _avatarColorsForSeed(int seed) {
  const colorSets = <List<Color>>[
    [Color(0xFFE84C72), Color(0xFFFFC857)],
    [Color(0xFF12C7B7), Color(0xFF7A5CFF)],
    [Color(0xFF251538), Color(0xFFE84C72)],
    [Color(0xFFFF7A45), Color(0xFF12C7B7)],
  ];
  return colorSets[seed.abs() % colorSets.length];
}

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({
    required this.user,
    required this.busy,
    required this.onUnblockTap,
  });

  final BlockedRoomUser user;
  final bool busy;
  final VoidCallback onUnblockTap;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                const SizedBox(height: 9),
                _MiniActionPill(
                  icon: Icons.remove_circle_outline_rounded,
                  label: busy ? 'Unblocking...' : 'Unblock',
                  color: RoomColors.aqua,
                  onTap: busy ? null : onUnblockTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedNotice extends StatelessWidget {
  const _BlockedNotice({
    required this.usingLocalFallback,
    required this.onRetry,
  });

  final bool usingLocalFallback;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final color = usingLocalFallback ? RoomColors.coral : RoomColors.gold;
    final message = usingLocalFallback
        ? 'Backend unavailable. Showing local sample blocked list for UI testing.'
        : 'Blocked users load from the backend. Unblock removes the active kickout entry.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(usingLocalFallback ? Icons.cloud_off_rounded : Icons.info_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: RoomColors.plum,
                fontSize: 11.2,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (usingLocalFallback) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: RoomColors.coral,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: onTap == null ? 0.06 : 0.11),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color.withValues(alpha: onTap == null ? 0.55 : 1), size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: onTap == null ? 0.55 : 1),
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
  const _BlockedEmptyState({
    required this.usingLocalFallback,
    required this.onRestoreTap,
  });

  final bool usingLocalFallback;
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
          Text(
            usingLocalFallback
                ? 'This local sample list is empty right now.'
                : 'This room has no active backend blocked users right now.',
            textAlign: TextAlign.center,
            style: const TextStyle(
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
