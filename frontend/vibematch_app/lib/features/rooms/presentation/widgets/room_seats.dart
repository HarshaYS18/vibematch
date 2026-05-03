import 'dart:math' as math;

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
  static const double seatHeight = 106;
  static const double rowHeight = 116;
  static const double avatarSize = 62;
  static const double menuWidth = 82;
  static const double menuItemHeight = 34;
  static const double menuArrowHeight = 9;

  int? _hiddenMenuSeat;
  OverlayEntry? _menuEntry;
  int? _overlaySeatIndex;
  bool? _overlaySeatLocked;
  Size? _lastLayoutSize;
  SeatLayoutSpec? _lastSpec;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverlayMenu());
  }

  @override
  void dispose() {
    roomSeatActionDismissSignal.removeListener(_hideMenu);
    _removeOverlayMenu();
    super.dispose();
  }

  void _hideMenu() {
    if (!mounted || widget.selectedSeatIndex == null) return;
    setState(() => _hiddenMenuSeat = widget.selectedSeatIndex);
    _removeOverlayMenu();
  }

  void _removeOverlayMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
    _overlaySeatIndex = null;
    _overlaySeatLocked = null;
  }

  void _syncOverlayMenu() {
    if (!mounted) return;

    final selectedSeat = _selectedSeat;
    final layoutSize = _lastLayoutSize;
    final spec = _lastSpec;

    if (selectedSeat == null || layoutSize == null || spec == null) {
      _removeOverlayMenu();
      return;
    }

    if (_overlaySeatIndex == selectedSeat.index && _overlaySeatLocked == selectedSeat.locked && _menuEntry != null) {
      _menuEntry!.markNeedsBuild();
      return;
    }

    _removeOverlayMenu();

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final seatTopLeft = _seatOffset(selectedSeat.index, spec, layoutSize.width);
    final localLeft = seatTopLeft.dx - (menuWidth / 2);
    final localTop = seatTopLeft.dy + seatHeight + 3;
    final globalPosition = renderBox.localToGlobal(Offset(localLeft, localTop));
    final screenWidth = MediaQuery.sizeOf(context).width;
    final left = globalPosition.dx.clamp(6.0, screenWidth - menuWidth - 6);
    final top = globalPosition.dy;

    _overlaySeatIndex = selectedSeat.index;
    _overlaySeatLocked = selectedSeat.locked;

    _menuEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: left,
        top: top,
        width: menuWidth,
        child: _SeatMenu(
          key: ValueKey('seat-menu-${selectedSeat.index}-${selectedSeat.locked}'),
          locked: selectedSeat.locked,
          onInvite: () => _runMenuAction(() => widget.onInvite(selectedSeat.index)),
          onSwitch: () => _runMenuAction(() => widget.onSwitch(selectedSeat.index)),
          onLock: () => _runMenuAction(() => widget.onLock(selectedSeat.index)),
          onUnlock: () => _runMenuAction(() => widget.onUnlock(selectedSeat.index)),
        ),
      ),
    );

    overlay.insert(_menuEntry!);
  }

  void _runMenuAction(VoidCallback action) {
    dismissRoomSeatActionPill();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final spec = SeatLayoutSpec.parse(widget.layoutId);
    final topRows = spec.hasHostSeats ? 1 : 0;
    final totalRows = topRows + spec.rows;
    final layoutHeight = totalRows * rowHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        _lastLayoutSize = Size(width, layoutHeight);
        _lastSpec = spec;
        WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverlayMenu());

        final children = <Widget>[];

        for (var index = 0; index < widget.seats.length; index++) {
          final offset = _seatOffset(index, spec, width);
          final seat = widget.seats[index];
          final visuallyProtectedSeatOne = index == 0 && seat.user == null && !widget.canManageSeats;
          children.add(
            Positioned(
              left: offset.dx - (seatWidth / 2),
              top: offset.dy,
              width: seatWidth,
              height: seatHeight,
              child: _SeatTile(
                seat: seat,
                selected: widget.selectedSeatIndex == index && _hiddenMenuSeat != index,
                visuallyProtected: visuallyProtectedSeatOne,
                onTap: () {
                  final user = widget.seats[index].user;
                  if (user == null) {
                    widget.onSeatTap(index);
                  } else {
                    dismissRoomSeatActionPill();
                    widget.onUserTap(index);
                  }
                },
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
  const _SeatTile({
    required this.seat,
    required this.selected,
    required this.visuallyProtected,
    required this.onTap,
  });

  final RoomSeat seat;
  final bool selected;
  final bool visuallyProtected;
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
          _SeatAvatar(
            seat: seat,
            selected: selected,
            visuallyProtected: visuallyProtected,
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 24,
            child: user == null
                ? _EmptySeatLabel(index: seat.index, visuallyProtected: visuallyProtected)
                : _UserSeatLabel(user: user, index: seat.index),
          ),
        ],
      ),
    );
  }
}

class _SeatAvatar extends StatelessWidget {
  const _SeatAvatar({
    required this.seat,
    required this.selected,
    required this.visuallyProtected,
  });

  final RoomSeat seat;
  final bool selected;
  final bool visuallyProtected;

  bool get _lockedVisual => seat.locked || visuallyProtected;

  @override
  Widget build(BuildContext context) {
    final user = seat.user;
    final fogColor = _lockedVisual ? const Color(0xFFE7EDF7) : const Color(0xFFDFF9F7);
    final glowColor = _lockedVisual ? const Color(0xFFC9D4E6) : const Color(0xFF12C7B7);

    return SizedBox(
      width: _RoomSeatLayoutState.avatarSize + 18,
      height: _RoomSeatLayoutState.avatarSize + 18,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (_lockedVisual)
            CustomPaint(
              size: Size.square(_RoomSeatLayoutState.avatarSize + 14),
              painter: _DottedSeatRingPainter(
                color: Colors.white.withValues(alpha: 0.62),
                strokeWidth: 1.7,
                dashLength: 4.4,
                gapLength: 4.6,
              ),
            ),
          Container(
            width: _RoomSeatLayoutState.avatarSize + 12,
            height: _RoomSeatLayoutState.avatarSize + 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.28, -0.34),
                radius: 0.92,
                colors: [
                  fogColor.withValues(alpha: _lockedVisual ? 0.30 : 0.36),
                  Colors.white.withValues(alpha: _lockedVisual ? 0.10 : 0.16),
                  const Color(0xFF101522).withValues(alpha: _lockedVisual ? 0.54 : 0.44),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: _lockedVisual ? 0.14 : 0.20),
                  blurRadius: 17,
                  offset: const Offset(0, 7),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(-2, -2),
                ),
              ],
            ),
          ),
          if (selected)
            Container(
              width: _RoomSeatLayoutState.avatarSize + 9,
              height: _RoomSeatLayoutState.avatarSize + 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.92), width: 1.4),
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
                color: user == null ? null : null,
                gradient: user == null
                    ? RadialGradient(
                        center: const Alignment(-0.35, -0.42),
                        radius: 0.92,
                        colors: [
                          Colors.white.withValues(alpha: _lockedVisual ? 0.30 : 0.24),
                          fogColor.withValues(alpha: _lockedVisual ? 0.14 : 0.18),
                          const Color(0xFF232633).withValues(alpha: _lockedVisual ? 0.68 : 0.54),
                        ],
                      )
                    : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: user.avatarColors),
                border: Border.all(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.86)
                      : _lockedVisual
                          ? Colors.white.withValues(alpha: 0.24)
                          : Colors.white.withValues(alpha: 0.18),
                  width: selected ? 1.4 : 1.1,
                ),
              ),
              child: Center(
                child: user == null
                    ? Icon(
                        _lockedVisual ? Icons.lock_rounded : Icons.add_rounded,
                        color: Colors.white.withValues(alpha: _lockedVisual ? 0.82 : 0.76),
                        size: _lockedVisual ? 22 : 28,
                      )
                    : Text(
                        avatarLetter(user.name),
                        style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ),
          if (visuallyProtected)
            Positioned(
              right: 0,
              top: 5,
              child: Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  color: const Color(0xFFC99A3B).withValues(alpha: 0.94),
                  shape: BoxShape.circle,
                  border: Border.all(color: RoomColors.deep, width: 1.2),
                ),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 10.5),
              ),
            ),
          if (user?.selfMuted ?? false)
            Positioned(
              right: 0,
              bottom: 5,
              child: Container(
                width: 21,
                height: 21,
                decoration: BoxDecoration(
                  color: RoomColors.selfMute,
                  shape: BoxShape.circle,
                  border: Border.all(color: RoomColors.deep, width: 1.3),
                ),
                child: const Icon(Icons.mic_off_rounded, color: Colors.white, size: 11),
              ),
            ),
          if (user?.adminMuted ?? false)
            Positioned(
              right: 0,
              bottom: 5,
              child: Container(
                width: 21,
                height: 21,
                decoration: BoxDecoration(
                  color: RoomColors.coral,
                  shape: BoxShape.circle,
                  border: Border.all(color: RoomColors.deep, width: 1.3),
                  boxShadow: [
                    BoxShadow(color: RoomColors.coral.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: const Icon(Icons.mic_off_rounded, color: Colors.white, size: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _DottedSeatRingPainter extends CustomPainter {
  const _DottedSeatRingPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final circumference = 2 * math.pi * radius;
    final dashRadians = (dashLength / circumference) * 2 * math.pi;
    final gapRadians = (gapLength / circumference) * 2 * math.pi;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    var start = -math.pi / 2;
    while (start < math.pi * 1.5) {
      canvas.drawArc(rect, start, dashRadians, false, paint);
      start += dashRadians + gapRadians;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedSeatRingPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength;
  }
}

class _EmptySeatLabel extends StatelessWidget {
  const _EmptySeatLabel({required this.index, required this.visuallyProtected});

  final int index;
  final bool visuallyProtected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        visuallyProtected ? 'HOST' : 'NO.${index + 1}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: visuallyProtected ? 0.68 : 0.58),
          fontSize: 11.2,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: visuallyProtected ? 0.4 : 0,
        ),
      ),
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

class _SeatMenu extends StatefulWidget {
  const _SeatMenu({
    super.key,
    required this.locked,
    required this.onInvite,
    required this.onSwitch,
    required this.onLock,
    required this.onUnlock,
  });

  final bool locked;
  final VoidCallback onInvite;
  final VoidCallback onSwitch;
  final VoidCallback onLock;
  final VoidCallback onUnlock;

  @override
  State<_SeatMenu> createState() => _SeatMenuState();
}

class _SeatMenuState extends State<_SeatMenu> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 210), reverseDuration: const Duration(milliseconds: 140));
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack, reverseCurve: Curves.easeInBack);
    _opacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic));
    _scale = Tween<double>(begin: 0.88, end: 1).animate(curve);
    _slide = Tween<Offset>(begin: const Offset(0, -0.18), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInBack));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.locked
        ? [_MenuAction('Unlock', widget.onUnlock)]
        : [_MenuAction('Invite', widget.onInvite), _MenuAction('Switch', widget.onSwitch), _MenuAction('Lock', widget.onLock)];

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SeatMenuPointer(),
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                elevation: 10,
                shadowColor: Colors.black.withValues(alpha: 0.16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5F6470).withValues(alpha: 0.76),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 14, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        _MenuButton(action: actions[i]),
                        if (i != actions.length - 1)
                          Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 2.5, horizontal: 4), color: Colors.white.withValues(alpha: 0.11)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatMenuPointer extends StatelessWidget {
  const _SeatMenuPointer();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(18, _RoomSeatLayoutState.menuArrowHeight), painter: _SeatMenuPointerPainter());
  }
}

class _SeatMenuPointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5F6470).withValues(alpha: 0.76)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MenuAction {
  const _MenuAction(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.action});

  final _MenuAction action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: action.onTap,
      child: SizedBox(
        height: _RoomSeatLayoutState.menuItemHeight,
        child: Center(
          child: Text(
            action.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12.8, fontWeight: FontWeight.w900, height: 1),
          ),
        ),
      ),
    );
  }
}
