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
    required this.applyOnlyModeEnabled,
    required this.onSeatTap,
    required this.onUserTap,
    required this.onInvite,
    required this.onSwitch,
    required this.onLock,
    required this.onUnlock,
    required this.onApply,
  });

  final List<RoomSeat> seats;
  final String layoutId;
  final int? selectedSeatIndex;
  final bool canManageSeats;
  final bool applyOnlyModeEnabled;
  final ValueChanged<int> onSeatTap;
  final ValueChanged<int> onUserTap;
  final ValueChanged<int> onInvite;
  final ValueChanged<int> onSwitch;
  final ValueChanged<int> onLock;
  final ValueChanged<int> onUnlock;
  final ValueChanged<int> onApply;

  @override
  State<RoomSeatLayout> createState() => _RoomSeatLayoutState();
}

class _RoomSeatLayoutState extends State<RoomSeatLayout> {
  static const double seatWidth = 76;
  static const double seatHeight = 88;
  static const double rowHeight = 94;
  static const double avatarSize = 49;
  static const double menuWidth = 72;
  static const double menuItemHeight = 28;
  static const double menuArrowHeight = 7;

  int? _hiddenMenuSeat;
  OverlayEntry? _menuEntry;
  int? _overlaySeatIndex;
  bool? _overlaySeatLocked;
  bool? _overlayApplyOnly;
  bool? _overlayCanManage;
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
    if (oldWidget.selectedSeatIndex != widget.selectedSeatIndex) _hiddenMenuSeat = null;
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
    _overlayApplyOnly = null;
    _overlayCanManage = null;
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
    if (_overlaySeatIndex == selectedSeat.index && _overlaySeatLocked == selectedSeat.locked && _overlayApplyOnly == widget.applyOnlyModeEnabled && _overlayCanManage == widget.canManageSeats && _menuEntry != null) {
      _menuEntry!.markNeedsBuild();
      return;
    }
    _removeOverlayMenu();
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final seatTopLeft = _seatOffset(selectedSeat.index, spec, layoutSize.width);
    final localLeft = seatTopLeft.dx - (menuWidth / 2);
    final localTop = seatTopLeft.dy + seatHeight + 2;
    final globalPosition = renderBox.localToGlobal(Offset(localLeft, localTop));
    final screenWidth = MediaQuery.sizeOf(context).width;
    final left = globalPosition.dx.clamp(6.0, screenWidth - menuWidth - 6);
    final top = globalPosition.dy;
    _overlaySeatIndex = selectedSeat.index;
    _overlaySeatLocked = selectedSeat.locked;
    _overlayApplyOnly = widget.applyOnlyModeEnabled;
    _overlayCanManage = widget.canManageSeats;
    _menuEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: left,
        top: top,
        width: menuWidth,
        child: _SeatMenu(
          key: ValueKey('seat-menu-${selectedSeat.index}-${selectedSeat.locked}-${widget.applyOnlyModeEnabled}-${widget.canManageSeats}'),
          locked: selectedSeat.locked,
          applyOnlyModeEnabled: widget.applyOnlyModeEnabled,
          canManageSeats: widget.canManageSeats,
          onInvite: () => _runMenuAction(() => widget.onInvite(selectedSeat.index)),
          onSwitch: () => _runMenuAction(() => widget.onSwitch(selectedSeat.index)),
          onLock: () => _runMenuAction(() => widget.onLock(selectedSeat.index)),
          onUnlock: () => _runMenuAction(() => widget.onUnlock(selectedSeat.index)),
          onApply: () => _runMenuAction(() => widget.onApply(selectedSeat.index)),
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
          children.add(Positioned(
            left: offset.dx - (seatWidth / 2),
            top: offset.dy,
            width: seatWidth,
            height: seatHeight,
            child: _SeatTile(
              seat: widget.seats[index],
              selected: widget.selectedSeatIndex == index && _hiddenMenuSeat != index,
              onTap: () {
                final seat = widget.seats[index];
                final user = seat.user;
                if (user == null) {
                  if (widget.applyOnlyModeEnabled && !widget.canManageSeats && !seat.locked) {
                    dismissRoomSeatActionPill();
                    widget.onApply(index);
                    return;
                  }
                  widget.onSeatTap(index);
                } else {
                  dismissRoomSeatActionPill();
                  widget.onUserTap(index);
                }
              },
            ),
          ));
        }
        return SizedBox(height: layoutHeight, width: width, child: Stack(clipBehavior: Clip.none, children: children));
      },
    );
  }

  RoomSeat? get _selectedSeat {
    final index = widget.selectedSeatIndex;
    if (index == null || index < 0 || index >= widget.seats.length) return null;
    if (_hiddenMenuSeat == index) return null;
    final seat = widget.seats[index];
    if (seat.user != null) return null;
    if (widget.canManageSeats) return seat;
    return null;
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
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: Column(mainAxisSize: MainAxisSize.min, children: [
      _SeatAvatar(seat: seat, selected: selected),
      const SizedBox(height: 3),
      SizedBox(height: 19, child: user == null ? _EmptySeatLabel(index: seat.index) : _UserSeatLabel(user: user, index: seat.index)),
    ]));
  }
}

class _SeatAvatar extends StatelessWidget {
  const _SeatAvatar({required this.seat, required this.selected});
  final RoomSeat seat;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final user = seat.user;
    final avatarUrl = user?.avatarUrl?.trim();
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final equippedFrame = user == null
        ? null
        : equippedStoreAvatarFrame(
            userId: user.id,
            assetPath: user.equippedAvatarFrameAssetPath,
            imageUrl: user.equippedAvatarFrameImageUrl,
          );
    return SizedBox(width: _RoomSeatLayoutState.avatarSize + 11, height: _RoomSeatLayoutState.avatarSize + 11, child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
      if (selected) Container(width: _RoomSeatLayoutState.avatarSize + 6, height: _RoomSeatLayoutState.avatarSize + 6, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.15))),
      RoomAvatarFrameHost(
        frame: user == null ? null : (equippedFrame ?? defaultStaticAvatarFrame),
        size: _RoomSeatLayoutState.avatarSize,
        framePadding: equippedFrame == null ? 6 : 16,
        child: Container(
          width: _RoomSeatLayoutState.avatarSize,
          height: _RoomSeatLayoutState.avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: user == null ? Colors.white.withValues(alpha: seat.locked ? 0.08 : 0.12) : null,
            gradient: user == null || hasAvatar ? null : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: user.avatarColors),
            border: Border.all(color: selected ? Colors.white.withValues(alpha: 0.84) : Colors.white.withValues(alpha: 0.16), width: selected ? 1.15 : 0.95),
          ),
          clipBehavior: Clip.antiAlias,
          child: user == null
              ? Center(child: Icon(seat.locked ? Icons.lock_rounded : Icons.add_rounded, color: Colors.white70, size: seat.locked ? 17 : 21))
              : hasAvatar
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) => _SeatAvatarFallback(user: user),
                    )
                  : _SeatAvatarFallback(user: user),
        ),
      ),
      if (user?.selfMuted ?? false) Positioned(right: 1, bottom: 4, child: Container(width: 17, height: 17, decoration: BoxDecoration(color: RoomColors.selfMute, shape: BoxShape.circle, border: Border.all(color: RoomColors.deep, width: 1.0)), child: const Icon(Icons.mic_off_rounded, color: Colors.white, size: 8.8))),
      if (user?.adminMuted ?? false) Positioned(right: 1, bottom: 4, child: Container(width: 17, height: 17, decoration: BoxDecoration(color: RoomColors.coral, shape: BoxShape.circle, border: Border.all(color: RoomColors.deep, width: 1.0), boxShadow: [BoxShadow(color: RoomColors.coral.withValues(alpha: 0.30), blurRadius: 6, offset: const Offset(0, 2))]), child: const Icon(Icons.mic_off_rounded, color: Colors.white, size: 8.8))),
    ]));
  }
}

class _SeatAvatarFallback extends StatelessWidget {
  const _SeatAvatarFallback({required this.user});
  final SeatUser user;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: user.avatarColors)),
      child: Center(child: Text(avatarLetter(user.name), style: const TextStyle(color: Colors.white, fontSize: 18.5, fontWeight: FontWeight.w900))),
    );
  }
}

class _EmptySeatLabel extends StatelessWidget {
  const _EmptySeatLabel({required this.index});
  final int index;
  @override
  Widget build(BuildContext context) => Center(child: Text('NO.${index + 1}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.56), fontSize: 9.4, fontWeight: FontWeight.w900, height: 1)));
}

class _UserSeatLabel extends StatelessWidget {
  const _UserSeatLabel({required this.user, required this.index});
  final SeatUser user;
  final int index;
  @override
  Widget build(BuildContext context) {
    final chipColor = user.gender == RoomUserGender.female ? RoomColors.coral : RoomColors.aqua;
    return Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
      Container(width: 13, height: 13, alignment: Alignment.center, decoration: BoxDecoration(color: chipColor, shape: BoxShape.circle), child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 6.8, fontWeight: FontWeight.w900, height: 1))),
      const SizedBox(width: 3),
      Flexible(child: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10.3, fontWeight: FontWeight.w900, height: 1))),
    ]);
  }
}

class _SeatMenu extends StatefulWidget {
  const _SeatMenu({super.key, required this.locked, required this.applyOnlyModeEnabled, required this.canManageSeats, required this.onInvite, required this.onSwitch, required this.onLock, required this.onUnlock, required this.onApply});
  final bool locked;
  final bool applyOnlyModeEnabled;
  final bool canManageSeats;
  final VoidCallback onInvite;
  final VoidCallback onSwitch;
  final VoidCallback onLock;
  final VoidCallback onUnlock;
  final VoidCallback onApply;
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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 190), reverseDuration: const Duration(milliseconds: 125));
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack, reverseCurve: Curves.easeInBack);
    _opacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic));
    _scale = Tween<double>(begin: 0.88, end: 1).animate(curve);
    _slide = Tween<Offset>(begin: const Offset(0, -0.14), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInBack));
    _controller.forward();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final actions = widget.canManageSeats ? widget.locked ? [_MenuAction('Unlock', widget.onUnlock)] : [_MenuAction('Invite', widget.onInvite), _MenuAction('Switch', widget.onSwitch), _MenuAction('Lock', widget.onLock)] : <_MenuAction>[];
    if (actions.isEmpty) return const SizedBox.shrink();
    return FadeTransition(opacity: _opacity, child: SlideTransition(position: _slide, child: ScaleTransition(scale: _scale, alignment: Alignment.topCenter, child: Column(mainAxisSize: MainAxisSize.min, children: [
      const _SeatMenuPointer(),
      Material(color: Colors.transparent, borderRadius: BorderRadius.circular(13), elevation: 7, shadowColor: Colors.black.withValues(alpha: 0.13), child: Container(padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5), decoration: BoxDecoration(color: const Color(0xFF5F6470).withValues(alpha: 0.75), borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white.withValues(alpha: 0.13)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.13), blurRadius: 10, offset: const Offset(0, 5))]), child: Column(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < actions.length; i++) ...[_MenuButton(action: actions[i]), if (i != actions.length - 1) Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 1.8, horizontal: 4), color: Colors.white.withValues(alpha: 0.10))]]))),
    ]))));
  }
}

class _SeatMenuPointer extends StatelessWidget {
  const _SeatMenuPointer();
  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(15, _RoomSeatLayoutState.menuArrowHeight), painter: _SeatMenuPointerPainter());
}

class _SeatMenuPointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF5F6470).withValues(alpha: 0.75)..style = PaintingStyle.fill;
    final path = Path()..moveTo(size.width / 2, 0)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MenuAction { const _MenuAction(this.label, this.onTap); final String label; final VoidCallback onTap; }

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.action});
  final _MenuAction action;
  @override
  Widget build(BuildContext context) => InkWell(borderRadius: BorderRadius.circular(9), onTap: action.onTap, child: SizedBox(height: _RoomSeatLayoutState.menuItemHeight, child: Center(child: Text(action.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10.9, fontWeight: FontWeight.w900, height: 1)))));
}
