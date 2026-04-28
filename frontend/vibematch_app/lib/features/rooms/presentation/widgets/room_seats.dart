import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_theme.dart';

class RoomSeatLayout extends StatelessWidget {
  const RoomSeatLayout({
    super.key,
    required this.seats,
    required this.layoutId,
    required this.selectedSeatIndex,
    required this.canManageSeats,
    required this.onSeatTap,
    required this.onUserTap,
    required this.onInvite,
    required this.onSwitch,
    required this.onLock,
    required this.onUnlock,
  });

  final List<RoomSeat> seats;
  final String layoutId;
  final int? selectedSeatIndex;
  final bool canManageSeats;
  final ValueChanged<int> onSeatTap;
  final ValueChanged<int> onUserTap;
  final ValueChanged<int> onInvite;
  final ValueChanged<int> onSwitch;
  final ValueChanged<int> onLock;
  final ValueChanged<int> onUnlock;

  @override
  Widget build(BuildContext context) {
    final spec = SeatLayoutSpec.parse(layoutId);
    final children = <Widget>[];
    var cursor = 0;

    if (spec.hasHostSeats) {
      children.add(
        SizedBox(
          height: 90,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(spec.topSeatCount, (i) {
              if (i >= seats.length) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: SizedBox(width: 72, height: 90, child: _buildSeat(seats[i])),
              );
            }),
          ),
        ),
      );
      children.add(const SizedBox(height: 5));
      cursor = spec.topSeatCount;
    }

    for (var row = 0; row < spec.rows; row++) {
      children.add(
        SizedBox(
          height: selectedSeatIndex != null ? 106 : 89,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(spec.columns, (col) {
              final seatIndex = cursor + (row * spec.columns) + col;
              if (seatIndex >= seats.length) return const Expanded(child: SizedBox.shrink());
              return Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(width: 74, height: 106, child: _buildSeat(seats[seatIndex])),
                ),
              );
            }),
          ),
        ),
      );
      children.add(SizedBox(height: selectedSeatIndex != null ? 2 : 4));
    }

    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _buildSeat(RoomSeat seat) {
    final selected = selectedSeatIndex == seat.index;
    final user = seat.user;
    final showActions = selected && user == null && canManageSeats;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => user == null ? onSeatTap(seat.index) : onUserTap(seat.index),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SeatAvatar(seat: seat, selected: selected),
              const SizedBox(height: 4),
              SizedBox(
                width: 74,
                child: Text(
                  user?.name ?? 'NO.${seat.index + 1}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: user == null ? 0.58 : 0.96),
                    fontSize: 10.2,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showActions)
          Positioned(
            top: 67,
            child: seat.locked
                ? _SeatActionCapsule(
                    actions: [
                      _SeatActionData(
                        icon: Icons.lock_open_rounded,
                        label: 'Unlock',
                        onTap: () => onUnlock(seat.index),
                      ),
                    ],
                  )
                : _SeatActionCapsule(
                    actions: [
                      _SeatActionData(
                        icon: Icons.person_add_alt_1_rounded,
                        label: 'Invite',
                        onTap: () => onInvite(seat.index),
                      ),
                      _SeatActionData(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Switch',
                        onTap: () => onSwitch(seat.index),
                      ),
                      _SeatActionData(
                        icon: Icons.lock_outline_rounded,
                        label: 'Lock',
                        onTap: () => onLock(seat.index),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}

class _SeatAvatar extends StatelessWidget {
  const _SeatAvatar({required this.seat, required this.selected});

  final RoomSeat seat;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final user = seat.user;
    const size = 56.0;
    final borderColor = selected
        ? RoomColors.gold
        : user == null
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.24);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (selected)
          Container(
            width: size + 10,
            height: size + 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  RoomColors.gold.withValues(alpha: 0.04),
                  RoomColors.gold.withValues(alpha: 0.50),
                  RoomColors.aqua.withValues(alpha: 0.32),
                  RoomColors.gold.withValues(alpha: 0.04),
                ],
              ),
            ),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: user == null ? Colors.white.withValues(alpha: seat.locked ? 0.09 : 0.12) : null,
            gradient: user == null ? null : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: user.avatarColors),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: RoomColors.gold.withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              if (user != null)
                BoxShadow(
                  color: user.avatarColors.first.withValues(alpha: 0.23),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
            ],
          ),
          child: Center(
            child: user == null
                ? Icon(
                    seat.locked ? Icons.lock_rounded : Icons.add_rounded,
                    color: Colors.white.withValues(alpha: seat.locked ? 0.50 : 0.70),
                    size: seat.locked ? 22 : 25,
                  )
                : Text(
                    avatarLetter(user.name),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
          ),
        ),
        if (user?.isHost ?? false)
          const Positioned(
            top: -5,
            child: _SeatRoleBadge(label: 'HOST', color: RoomColors.gold),
          )
        else if (user?.isRoomAdmin ?? false)
          const Positioned(
            top: -5,
            child: _SeatRoleBadge(label: 'ADMIN', color: RoomColors.aqua),
          ),
        if (user?.muted ?? false)
          Positioned(
            right: -2,
            bottom: 2,
            child: Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: user!.adminMuted ? RoomColors.adminMute : RoomColors.selfMute,
                shape: BoxShape.circle,
                border: Border.all(color: RoomColors.deep, width: 1.2),
              ),
              child: const Icon(Icons.mic_off_rounded, color: Colors.white, size: 10),
            ),
          ),
        if (seat.locked && user == null)
          Positioned(
            right: -1,
            top: 3,
            child: Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Icon(Icons.lock_rounded, color: Colors.white70, size: 9),
            ),
          ),
      ],
    );
  }
}

class _SeatRoleBadge extends StatelessWidget {
  const _SeatRoleBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 15,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.32), width: 0.7),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 7.4,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}

class _SeatActionCapsule extends StatelessWidget {
  const _SeatActionCapsule({required this.actions});

  final List<_SeatActionData> actions;

  @override
  Widget build(BuildContext context) {
    final width = actions.length == 1 ? 104.0 : 232.0;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xF2070414),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: RoomColors.gold.withValues(alpha: 0.26)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.46),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: RoomColors.gold.withValues(alpha: 0.09),
              blurRadius: 18,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              Expanded(child: _SeatActionButton(action: actions[i])),
              if (i != actions.length - 1)
                Container(
                  width: 1,
                  height: 18,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeatActionButton extends StatelessWidget {
  const _SeatActionButton({required this.action});

  final _SeatActionData action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: action.onTap,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, color: Colors.white, size: 13.5),
            const SizedBox(width: 4),
            Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatActionData {
  const _SeatActionData({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}
