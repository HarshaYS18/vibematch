import 'package:flutter/material.dart';

import '../../../vibesync/models/vibesync_models.dart';
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
  static const double _seatWidth = 76;
  static const double _seatHeight = 88;
  static const double _rowHeight = 106;
  static const double _hostRowHeight = 106;
  static const double _avatarSize = 56;
  static const double _actionWidth = 108;
  static const double _actionItemHeight = 30;
  static const double _actionPaddingY = 7;
  static const double _actionDividerAndMargin = 7;

  int? _visuallyHiddenSeatIndex;

  @override
  void initState() {
    super.initState();
    roomSeatActionDismissSignal.addListener(_hideActionMenuOnly);
  }

  @override
  void didUpdateWidget(covariant RoomSeatLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSeatIndex != widget.selectedSeatIndex) {
      _visuallyHiddenSeatIndex = null;
    }
  }

  @override
  void dispose() {
    roomSeatActionDismissSignal.removeListener(_hideActionMenuOnly);
    super.dispose();
  }

  void _hideActionMenuOnly() {
    if (widget.selectedSeatIndex == null) return;
    if (mounted) setState(() => _visuallyHiddenSeatIndex = widget.selectedSeatIndex);
  }

  @override
  Widget build(BuildContext context) {
    final spec = SeatLayoutSpec.parse(widget.layoutId);
    final selectedSeat = _selectedSeatForActions;
    final actionHeight = selectedSeat == null ? 0.0 : _actionMenuHeight(selectedSeat.locked ? 1 : 3);
    final hostHeight = spec.hasHostSeats ? _hostRowHeight : 0.0;
    final gridHeight = hostHeight + (spec.rows * _rowHeight);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final children = <Widget>[];

        if (selectedSeat != null) {
          children.add(
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(() => _visuallyHiddenSeatIndex = selectedSeat.index),
                child: const SizedBox.expand(),
              ),
            ),
          );
        }

        if (spec.hasHostSeats) {
          final hostCellWidth = width / spec.topSeatCount;
          for (var i = 0; i < spec.topSeatCount; i++) {
            if (i >= widget.seats.length) continue;
            children.add(
              Positioned(
                left: (hostCellWidth * i) + ((hostCellWidth - _seatWidth) / 2),
                top: 0,
                width: _seatWidth,
                height: _seatHeight,
                child: _buildSeat(widget.seats[i]),
              ),
            );
          }
        }

        final cursor = spec.hasHostSeats ? spec.topSeatCount : 0;
        final cellWidth = width / spec.columns;
        for (var row = 0; row < spec.rows; row++) {
          for (var col = 0; col < spec.columns; col++) {
            final seatIndex = cursor + (row * spec.columns) + col;
            if (seatIndex >= widget.seats.length) continue;
            children.add(
              Positioned(
                left: (cellWidth * col) + ((cellWidth - _seatWidth) / 2),
                top: hostHeight + (row * _rowHeight),
                width: _seatWidth,
                height: _seatHeight,
                child: _buildSeat(widget.seats[seatIndex]),
              ),
            );
          }
        }

        if (selectedSeat != null) {
          final position = _seatCenterPosition(selectedSeat.index, spec: spec, width: width);
          final placement = _actionMenuPlacement(
            seatCenter: position,
            width: width,
            gridHeight: gridHeight,
            actionHeight: actionHeight,
          );

          children.add(
            Positioned(
              left: placement.dx,
              top: placement.dy,
              width: _actionWidth,
              child: _SeatActionMenu(
                actions: selectedSeat.locked
                    ? [
                        _SeatActionData(
                          icon: Icons.lock_open_rounded,
                          label: 'Unlock',
                          onTap: () => widget.onUnlock(selectedSeat.index),
                        ),
                      ]
                    : [
                        _SeatActionData(
                          icon: Icons.person_add_alt_1_rounded,
                          label: 'Invite',
                          onTap: () => widget.onInvite(selectedSeat.index),
                        ),
                        _SeatActionData(
                          icon: Icons.swap_horiz_rounded,
                          label: 'Switch',
                          onTap: () => widget.onSwitch(selectedSeat.index),
                        ),
                        _SeatActionData(
                          icon: Icons.lock_outline_rounded,
                          label: 'Lock',
                          onTap: () => widget.onLock(selectedSeat.index),
                        ),
                      ],
              ),
            ),
          );
        }

        return SizedBox(
          height: gridHeight,
          width: width,
          child: Stack(clipBehavior: Clip.none, children: children),
        );
      },
    );
  }

  double _actionMenuHeight(int actionCount) {
    final dividers = actionCount <= 1 ? 0.0 : (actionCount - 1) * _actionDividerAndMargin;
    return (_actionPaddingY * 2) + (actionCount * _actionItemHeight) + dividers;
  }

  Offset _actionMenuPlacement({
    required Offset seatCenter,
    required double width,
    required double gridHeight,
    required double actionHeight,
  }) {
    final left = (seatCenter.dx - (_actionWidth / 2)).clamp(0.0, width - _actionWidth);
    final desiredBelow = seatCenter.dy + (_avatarSize / 2) + 12;
    final desiredAbove = seatCenter.dy - (_avatarSize / 2) - actionHeight - 12;

    final top = desiredBelow + actionHeight <= gridHeight
        ? desiredBelow
        : desiredAbove >= 0
            ? desiredAbove
            : (gridHeight - actionHeight).clamp(0.0, gridHeight);

    return Offset(left, top);
  }

  RoomSeat? get _selectedSeatForActions {
    final index = widget.selectedSeatIndex;
    if (index == null || !widget.canManageSeats || index < 0 || index >= widget.seats.length) return null;
    if (_visuallyHiddenSeatIndex == index) return null;
    final seat = widget.seats[index];
    if (seat.user != null) return null;
    return seat;
  }

  Offset _seatCenterPosition(int index, {required SeatLayoutSpec spec, required double width}) {
    if (spec.hasHostSeats && index < spec.topSeatCount) {
      final hostCellWidth = width / spec.topSeatCount;
      return Offset((hostCellWidth * index) + (hostCellWidth / 2), _avatarSize / 2);
    }

    final cursor = spec.hasHostSeats ? spec.topSeatCount : 0;
    final gridIndex = index - cursor;
    final row = gridIndex ~/ spec.columns;
    final col = gridIndex % spec.columns;
    final cellWidth = width / spec.columns;
    final hostHeight = spec.hasHostSeats ? _hostRowHeight : 0.0;
    return Offset((cellWidth * col) + (cellWidth / 2), hostHeight + (row * _rowHeight) + (_avatarSize / 2));
  }

  Widget _buildSeat(RoomSeat seat) {
    final selected = widget.selectedSeatIndex == seat.index && _visuallyHiddenSeatIndex != seat.index;
    final user = seat.user;

    return GestureDetector(
      key: ValueKey('room_seat_${seat.index}_${user?.id ?? 'empty'}_${seat.locked}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => user == null ? widget.onSeatTap(seat.index) : widget.onUserTap(seat.index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SeatAvatar(seat: seat, selected: selected, size: _avatarSize),
          const SizedBox(height: 6),
          SizedBox(
            width: _seatWidth,
            height: 18,
            child: user == null ? _EmptySeatLabel(index: seat.index) : _GenderNameLabel(user: user, index: seat.index),
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
    return Text(
      'NO.${index + 1}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.56),
        fontSize: 10.4,
        fontWeight: FontWeight.w900,
        height: 1,
        letterSpacing: -0.1,
      ),
    );
  }
}

class _GenderNameLabel extends StatelessWidget {
  const _GenderNameLabel({required this.user, required this.index});

  final SeatUser user;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isFemale = user.gender == VibeSyncGender.female;
    final color = isFemale ? RoomColors.coral : RoomColors.aqua;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Text(
            '${index + 1}',
            style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w900, height: 1),
          ),
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.4,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _SeatAvatar extends StatelessWidget {
  const _SeatAvatar({required this.seat, required this.selected, required this.size});

  final RoomSeat seat;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final user = seat.user;
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
        RoomAvatarFrameHost(
          frame: user == null ? null : defaultStaticAvatarFrame,
          size: size,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: user == null ? Colors.white.withValues(alpha: seat.locked ? 0.09 : 0.12) : null,
              gradient: user == null ? null : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: user.avatarColors),
              border: Border.all(color: borderColor, width: selected ? 2 : 1),
              boxShadow: [
                if (selected) BoxShadow(color: RoomColors.gold.withValues(alpha: 0.20), blurRadius: 14, offset: const Offset(0, 7)),
                if (user != null) BoxShadow(color: user.avatarColors.first.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 6)),
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

class _SeatActionMenu extends StatelessWidget {
  const _SeatActionMenu({required this.actions});

  final List<_SeatActionData> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(20),
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.65),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: _RoomSeatLayoutState._actionPaddingY),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: RoomColors.gold.withValues(alpha: 0.38)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.70), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              _SeatActionButton(action: actions[i]),
              if (i != actions.length - 1) Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 3), color: Colors.white.withValues(alpha: 0.10)),
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
      borderRadius: BorderRadius.circular(13),
      onTap: action.onTap,
      child: SizedBox(
        height: _RoomSeatLayoutState._actionItemHeight,
        child: Row(
          children: [
            Icon(action.icon, color: Colors.white, size: 14),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11.4, fontWeight: FontWeight.w900, height: 1),
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
