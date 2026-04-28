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

  static const double _seatWidth = 74;
  static const double _seatHeight = 80;
  static const double _rowHeight = 92;
  static const double _hostRowHeight = 92;
  static const double _actionHeight = 40;
  static const double _actionWidth = 238;

  @override
  Widget build(BuildContext context) {
    final spec = SeatLayoutSpec.parse(layoutId);
    final hasSelectedEmptyManageableSeat = _selectedSeatForActions != null;
    final hostHeight = spec.hasHostSeats ? _hostRowHeight : 0.0;
    final gridHeight = hostHeight + (spec.rows * _rowHeight);
    final layoutHeight = gridHeight + (hasSelectedEmptyManageableSeat ? _actionHeight + 6 : 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final children = <Widget>[];

        if (spec.hasHostSeats) {
          final hostCellWidth = width / spec.topSeatCount;
          for (var i = 0; i < spec.topSeatCount; i++) {
            if (i >= seats.length) continue;
            children.add(
              Positioned(
                left: (hostCellWidth * i) + ((hostCellWidth - _seatWidth) / 2),
                top: 0,
                width: _seatWidth,
                height: _seatHeight,
                child: _buildSeat(seats[i]),
              ),
            );
          }
        }

        final cursor = spec.hasHostSeats ? spec.topSeatCount : 0;
        final cellWidth = width / spec.columns;
        for (var row = 0; row < spec.rows; row++) {
          for (var col = 0; col < spec.columns; col++) {
            final seatIndex = cursor + (row * spec.columns) + col;
            if (seatIndex >= seats.length) continue;

            children.add(
              Positioned(
                left: (cellWidth * col) + ((cellWidth - _seatWidth) / 2),
                top: hostHeight + (row * _rowHeight),
                width: _seatWidth,
                height: _seatHeight,
                child: _buildSeat(seats[seatIndex]),
              ),
            );
          }
        }

        final selectedSeat = _selectedSeatForActions;
        if (selectedSeat != null) {
          final position = _seatCenterPosition(
            selectedSeat.index,
            spec: spec,
            width: width,
          );
          final left = (position.dx - (_actionWidth / 2)).clamp(0.0, width - _actionWidth);
          final top = (position.dy + 36).clamp(0.0, layoutHeight - _actionHeight);

          children.add(
            Positioned(
              left: left,
              top: top,
              width: _actionWidth,
              height: _actionHeight,
              child: _SeatActionCapsule(
                actions: selectedSeat.locked
                    ? [
                        _SeatActionData(
                          icon: Icons.lock_open_rounded,
                          label: 'Unlock',
                          onTap: () => onUnlock(selectedSeat.index),
                        ),
                      ]
                    : [
                        _SeatActionData(
                          icon: Icons.person_add_alt_1_rounded,
                          label: 'Invite',
                          onTap: () => onInvite(selectedSeat.index),
                        ),
                        _SeatActionData(
                          icon: Icons.swap_horiz_rounded,
                          label: 'Switch',
                          onTap: () => onSwitch(selectedSeat.index),
                        ),
                        _SeatActionData(
                          icon: Icons.lock_outline_rounded,
                          label: 'Lock',
                          onTap: () => onLock(selectedSeat.index),
                        ),
                      ],
              ),
            ),
          );
        }

        return SizedBox(
          height: layoutHeight,
          width: width,
          child: Stack(
            clipBehavior: Clip.none,
            children: children,
          ),
        );
      },
    );
  }

  RoomSeat? get _selectedSeatForActions {
    final index = selectedSeatIndex;
    if (index == null || !canManageSeats || index < 0 || index >= seats.length) return null;
    final seat = seats[index];
    if (seat.user != null) return null;
    return seat;
  }

  Offset _seatCenterPosition(int index, {required SeatLayoutSpec spec, required double width}) {
    if (spec.hasHostSeats && index < spec.topSeatCount) {
      final hostCellWidth = width / spec.topSeatCount;
      return Offset((hostCellWidth * index) + (hostCellWidth / 2), 28);
    }

    final cursor = spec.hasHostSeats ? spec.topSeatCount : 0;
    final gridIndex = index - cursor;
    final row = gridIndex ~/ spec.columns;
    final col = gridIndex % spec.columns;
    final cellWidth = width / spec.columns;
    final hostHeight = spec.hasHostSeats ? _hostRowHeight : 0.0;
    return Offset((cellWidth * col) + (cellWidth / 2), hostHeight + (row * _rowHeight) + 28);
  }

  Widget _buildSeat(RoomSeat seat) {
    final selected = selectedSeatIndex == seat.index;
    final user = seat.user;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => user == null ? onSeatTap(seat.index) : onUserTap(seat.index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SeatAvatar(seat: seat, selected: selected),
          const SizedBox(height: 5),
          SizedBox(
            width: _seatWidth,
            child: Text(
              user?.name ?? 'NO.${seat.index + 1}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: user == null ? 0.56 : 0.96),
                fontSize: 10.4,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
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
                  RoomColors.aqua.withValues(alpha: 0.28),
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
          const Positioned(top: -5, child: _SeatRoleBadge(label: 'HOST', color: RoomColors.gold))
        else if (user?.isRoomAdmin ?? false)
          const Positioned(top: -5, child: _SeatRoleBadge(label: 'ADMIN', color: RoomColors.aqua)),
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
                color: Colors.black.withValues(alpha: 0.50),
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
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 7.4, fontWeight: FontWeight.w900, height: 1, letterSpacing: 0.15),
      ),
    );
  }
}

class _SeatActionCapsule extends StatelessWidget {
  const _SeatActionCapsule({required this.actions});

  final List<_SeatActionData> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: RoomColors.gold.withValues(alpha: 0.34)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.66), blurRadius: 22, offset: const Offset(0, 10)),
              BoxShadow(color: RoomColors.gold.withValues(alpha: 0.12), blurRadius: 20),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                Expanded(child: _SeatActionButton(action: actions[i])),
                if (i != actions.length - 1)
                  Container(width: 1, height: 19, color: Colors.white.withValues(alpha: 0.10)),
              ],
            ],
          ),
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: action.onTap,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11.3, fontWeight: FontWeight.w900, height: 1, letterSpacing: -0.15),
              ),
            ],
          ),
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
