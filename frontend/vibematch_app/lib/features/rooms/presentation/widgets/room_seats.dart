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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(spec.topSeatCount, (i) {
            if (i >= seats.length) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(width: 68, height: 86, child: _buildSeat(seats[i])),
            );
          }),
        ),
      );
      children.add(const SizedBox(height: 8));
      cursor = spec.topSeatCount;
    }

    for (var row = 0; row < spec.rows; row++) {
      children.add(
        SizedBox(
          height: 88,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(spec.columns, (col) {
              final seatIndex = cursor + (row * spec.columns) + col;
              if (seatIndex >= seats.length) return const Expanded(child: SizedBox.shrink());
              return Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(width: 66, height: 86, child: _buildSeat(seats[seatIndex])),
                ),
              );
            }),
          ),
        ),
      );
      children.add(const SizedBox(height: 5));
    }

    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _buildSeat(RoomSeat seat) {
    final selected = selectedSeatIndex == seat.index;
    final user = seat.user;
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
              Text(
                user?.name ?? 'NO.${seat.index + 1}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: user == null ? 0.58 : 0.96),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        if (selected && user == null)
          Positioned(
            top: 67,
            child: seat.locked && canManageSeats
                ? _SeatActionOverlay(actions: [_SeatAction(icon: Icons.lock_open_rounded, label: 'Unlock', onTap: () => onUnlock(seat.index))])
                : !seat.locked && canManageSeats
                    ? _SeatActionOverlay(actions: [
                        _SeatAction(icon: Icons.person_add_alt_1_rounded, label: 'Invite', onTap: () => onInvite(seat.index)),
                        _SeatAction(icon: Icons.swap_horiz_rounded, label: 'Switch', onTap: () => onSwitch(seat.index)),
                        _SeatAction(icon: Icons.lock_outline_rounded, label: 'Lock', onTap: () => onLock(seat.index)),
                      ])
                    : const SizedBox.shrink(),
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
    const size = 54.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: user == null ? Colors.white.withValues(alpha: 0.13) : null,
            gradient: user == null ? null : LinearGradient(colors: user.avatarColors),
            border: Border.all(color: selected ? RoomColors.gold : Colors.white.withValues(alpha: user == null ? 0.13 : 0.22), width: selected ? 2 : 1),
            boxShadow: user == null ? [] : [BoxShadow(color: user.avatarColors.first.withValues(alpha: 0.20), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Center(
            child: user == null
                ? Icon(seat.locked ? Icons.lock_rounded : Icons.add_rounded, color: Colors.white.withValues(alpha: 0.68), size: 24)
                : Text(avatarLetter(user.name), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          ),
        ),
        if (user?.muted ?? false)
          Positioned(
            right: -2,
            bottom: 2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: user!.adminMuted ? RoomColors.adminMute : RoomColors.selfMute, shape: BoxShape.circle, border: Border.all(color: RoomColors.deep, width: 1)),
              child: const Icon(Icons.mic_off_rounded, color: Colors.white, size: 10),
            ),
          ),
      ],
    );
  }
}

class _SeatActionOverlay extends StatelessWidget {
  const _SeatActionOverlay({required this.actions});

  final List<_SeatAction> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF070414),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: RoomColors.gold.withValues(alpha: 0.20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              actions[i],
              if (i != actions.length - 1) const SizedBox(height: 13),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeatAction extends StatelessWidget {
  const _SeatAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        height: 30,
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
