import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_avatar_frames.dart';
import 'room_theme.dart';

final ValueNotifier<int> roomSeatActionDismissSignal = ValueNotifier<int>(0);

void dismissRoomSeatActionPill() {
  roomSeatActionDismissSignal.value++;
}

class RoomSeatLayout extends StatefulWidget {
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
  State<RoomSeatLayout> createState() => _RoomSeatLayoutState();
}

class _RoomSeatLayoutState extends State<RoomSeatLayout> {
  static const double seatWidth = 92;
  static const double seatHeight = 118;
  static const double rowHeight = 140;
  static const double avatarSize = 66;
  static const double menuWidth = 110;
  static const double menuItemHeight = 32;

  int? _hiddenMenuSeat;

  @override
  void initState() {
    super.initState();
    roomSeatActionDismissSignal.addListener(_hideMenu);
  }

  @override
  void didUpdateWidget(covariant RoomSeatLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSeatIndex != widget.selectedSeatIndex) {
      _hiddenMenuSeat = null;
    }
  }

  @override
  void dispose() {
    roomSeatActionDismissSignal.removeListener(_hideMenu);
    super.dispose();
  }

  void _hideMenu() {
    if (!mounted || widget.selectedSeatIndex == null) return;
    setState(() => _hiddenMenuSeat = widget.selectedSeatIndex);
  }

  @override
  Widget build(BuildContext context) {
    final spec = SeatLayoutSpec.parse(widget.layoutId);
    final selectedSeat = _selectedSeat;
    final topRows = spec.hasHostSeats ? 1 : 0;
    final totalRows = topRows + spec.rows;
    final layoutHeight = totalRows * rowHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final children = <Widget>[];

        for (var index = 0; index < widget.seats.length; index++) {
          final offset = _seatOffset(index, spec, width);
          children.add(
            Positioned(
              left: offset.dx - (seatWidth / 2),
              top: offset.dy,
              width: seatWidth,
              height: seatHeight,
              child: _SeatTile(
                seat: widget.seats[index],
                selected: widget.selectedSeatIndex == index && _hiddenMenuSeat != index,
                onTap: () {
                  final user = widget.seats[index].user;
                  user == null ? widget.onSeatTap(index) : widget.onUserTap(index);
                },
              ),
            ),
          );
        }

        if (selectedSeat != null) {
          final center = _seatOffset(selectedSeat.index, spec, width) + const Offset(0, avatarSize / 2);
          final menuHeight = selectedSeat.locked ? 52.0 : 132.0;
          final left = (center.dx - (menuWidth / 2)).clamp(0.0, (width - menuWidth).clamp(0.0, width));
          final below = center.dy + (avatarSize / 2) + 8;
          final above = center.dy - (avatarSize / 2) - menuHeight - 8;
          final top = below + menuHeight <= layoutHeight
              ? below
              : above >= 0
                  ? above
                  : (layoutHeight - menuHeight - 6).clamp(0.0, layoutHeight);

          children.add(
            Positioned(
              left: left,
              top: top,
              width: menuWidth,
              child: _SeatMenu(
                locked: selectedSeat.locked,
                onInvite: () => widget.onInvite(selectedSeat.index),
                onSwitch: () => widget.onSwitch(selectedSeat.index),
                onLock: () => widget.onLock(selectedSeat.index),
                onUnlock: () => widget.onUnlock(selectedSeat.index),
              ),
            ),
          );
        }

        return SizedBox(
          height: layoutHeight,
          width: width,
          child: Stack(clipBehavior: Clip.none, children: children),
        );
      },
    );
  }

  RoomSeat? get _selectedSeat {
    final index = widget.selectedSeatIndex;
    if (index == null || !widget.canManageSeats || index < 0 || index >= widget.seats.length) return null;
    if (_hiddenMenuSeat == index) return null;
    final seat = widget.seats[index];
    return seat.user == null ? seat : null;
  }

  Offset _seatOffset(int index, SeatLayoutSpec spec, double width) {
    if (spec.hasHostSeats && index < spec.topSeatCount) {
      final cell = width / spec.topSeatCount;
      return Offset((cell * index) + (cell / 2), 0);
    }

    final start = spec.hasHostSeats ? spec.topSeatCount : 0;
    final gridIndex = index - start;
    final row = gridIndex ~/ spec.columns;
    final column = gridIndex % spec.columns;
    final cell = width / spec.columns;
    final topOffset = spec.hasHostSeats ? rowHeight : 0.0;
    return Offset((cell * column) + (cell / 2), topOffset + (row * rowHeight));
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({required this.seat, required this.selected, required this.onTap});

  final RoomSeat seat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = seat.user;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SeatAvatar(seat: seat, selected: selected),
          const SizedBox(height: 8),
          SizedBox(
            height: 26,
            child: user == null ? _EmptySeatLabel(index: seat.index) : _UserSeatLabel(user: user, index: seat.index),
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
    return SizedBox(
      width: _RoomSeatLayoutState.avatarSize + 14,
      height: _RoomSeatLayoutState.avatarSize + 14,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (selected)
            Container(
              width: _RoomSeatLayoutState.avatarSize + 12,
              height: _RoomSeatLayoutState.avatarSize + 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [RoomColors.gold.withValues(alpha: 0.08), RoomColors.gold, RoomColors.aqua.withValues(alpha: 0.35), RoomColors.gold.withValues(alpha: 0.08)]),
              ),
            ),
          RoomAvatarFrameHost(
            frame: user == null ? null : defaultStaticAvatarFrame,
            size: _RoomSeatLayoutState.avatarSize,
            child: Container(
              width: _RoomSeatLayoutState.avatarSize,
              height: _RoomSeatLayoutState.avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: user == null ? Colors.white.withValues(alpha: seat.locked ? 0.08 : 0.12) : null,
                gradient: user == null ? null : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: user.avatarColors),
                border: Border.all(color: selected ? RoomColors.gold : Colors.white.withValues(alpha: 0.18), width: selected ? 2.2 : 1.1),
              ),
              child: Center(
                child: user == null
                    ? Icon(seat.locked ? Icons.lock_rounded : Icons.add_rounded, color: Colors.white70, size: seat.locked ? 24 : 30)
                    : Text(avatarLetter(user.name), style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
          if (user?.muted ?? false)
            Positioned(
              right: 0,
              bottom: 5,
              child: Container(
                width: 21,
                height: 21,
                decoration: BoxDecoration(color: RoomColors.selfMute, shape: BoxShape.circle, border: Border.all(color: RoomColors.deep, width: 1.3)),
                child: const Icon(Icons.mic_off_rounded, color: Colors.white, size: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptySeatLabel extends StatelessWidget {
  const _EmptySeatLabel({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('NO.${index + 1}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.58), fontSize: 11.2, fontWeight: FontWeight.w900, height: 1)),
    );
  }
}

class _UserSeatLabel extends StatelessWidget {
  const _UserSeatLabel({required this.user, required this.index});

  final SeatUser user;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isFemale = user.gender == RoomUserGender.female;
    final chipColor = isFemale ? RoomColors.coral : RoomColors.aqua;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: chipColor, shape: BoxShape.circle),
          child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 8.2, fontWeight: FontWeight.w900, height: 1)),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.2, fontWeight: FontWeight.w900, height: 1)),
        ),
      ],
    );
  }
}

class _SeatMenu extends StatelessWidget {
  const _SeatMenu({required this.locked, required this.onInvite, required this.onSwitch, required this.onLock, required this.onUnlock});

  final bool locked;
  final VoidCallback onInvite;
  final VoidCallback onSwitch;
  final VoidCallback onLock;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final actions = locked
        ? [_MenuAction(Icons.lock_open_rounded, 'Unlock', onUnlock)]
        : [_MenuAction(Icons.person_add_alt_1_rounded, 'Invite', onInvite), _MenuAction(Icons.swap_horiz_rounded, 'Switch', onSwitch), _MenuAction(Icons.lock_outline_rounded, 'Lock', onLock)];

    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(20),
      elevation: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20), border: Border.all(color: RoomColors.gold.withValues(alpha: 0.38))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              _MenuButton(action: actions[i]),
              if (i != actions.length - 1) Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 3), color: Colors.white.withValues(alpha: 0.10)),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuAction {
  const _MenuAction(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.action});

  final _MenuAction action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: action.onTap,
      child: SizedBox(
        height: _RoomSeatLayoutState.menuItemHeight,
        child: Row(
          children: [
            Icon(action.icon, color: Colors.white, size: 14),
            const SizedBox(width: 7),
            Expanded(child: Text(action.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.4, fontWeight: FontWeight.w900, height: 1))),
          ],
        ),
      ),
    );
  }
}
