import 'package:flutter/material.dart';

import '../../data/live_room_media_signaling_service.dart';
import '../live_room_models.dart';
import 'room_avatar_frames.dart';
import 'room_theme.dart';
import 'seat_speaking_wave.dart';

/// Seat layout for one mounted room.
///
/// Seat selection is owned by the room-scoped LiveRoomSeatController. Overlay
/// menu resources are widget-local and are removed directly by this state;
/// no process-global dismissal signal is used.
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
  static const double menuWidth = 72;
  static const double menuItemHeight = 26;
  static const double menuArrowHeight = 7;

  int? _hiddenMenuSeat;
  OverlayEntry? _menuEntry;
  int? _overlaySeatIndex;
  bool? _overlaySeatLocked;
  bool? _overlayCanManage;
  Size? _lastLayoutSize;
  SeatLayoutSpec? _lastSpec;
  _SeatMetrics? _lastMetrics;

  @override
  void didUpdateWidget(covariant RoomSeatLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSeatIndex != widget.selectedSeatIndex) _hiddenMenuSeat = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverlayMenu());
  }

  @override
  void dispose() {
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
    _overlayCanManage = null;
  }

  void _syncOverlayMenu() {
    if (!mounted) return;
    final selectedSeat = _selectedSeat;
    final layoutSize = _lastLayoutSize;
    final spec = _lastSpec;
    final metrics = _lastMetrics;
    if (selectedSeat == null || layoutSize == null || spec == null || metrics == null) {
      _removeOverlayMenu();
      return;
    }
    if (_overlaySeatIndex == selectedSeat.index && _overlaySeatLocked == selectedSeat.locked && _overlayCanManage == widget.canManageSeats && _menuEntry != null) {
      _menuEntry!.markNeedsBuild();
      return;
    }
    _removeOverlayMenu();
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final seatTopLeft = _seatOffset(selectedSeat.index, spec, layoutSize.width, metrics);
    final globalPosition = renderBox.localToGlobal(Offset(seatTopLeft.dx - (menuWidth / 2), seatTopLeft.dy + metrics.seatHeight + 2));
    final screenWidth = MediaQuery.sizeOf(context).width;
    _overlaySeatIndex = selectedSeat.index;
    _overlaySeatLocked = selectedSeat.locked;
    _overlayCanManage = widget.canManageSeats;
    _menuEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: globalPosition.dx.clamp(6.0, screenWidth - menuWidth - 6),
        top: globalPosition.dy,
        width: menuWidth,
        child: _SeatMenu(
          key: ValueKey('seat-menu-${selectedSeat.index}-${selectedSeat.locked}-${widget.canManageSeats}'),
          locked: selectedSeat.locked,
          canManageSeats: widget.canManageSeats,
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
    _hideMenu();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: LiveRoomMediaSignalingService.instance.mediaEngine.activeSpeakerPeerIds,
      builder: (context, activeSpeakerPeerIds, child) {
        final spec = SeatLayoutSpec.parse(widget.layoutId);
        final totalRows = (spec.hasHostSeats ? 1 : 0) + spec.rows;
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final metrics = _SeatMetrics.forLayout(width: width, spec: spec, totalSeats: widget.seats.length);
            final layoutHeight = totalRows * metrics.rowHeight;
            _lastLayoutSize = Size(width, layoutHeight);
            _lastSpec = spec;
            _lastMetrics = metrics;
            WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverlayMenu());
            final children = <Widget>[];
            for (var index = 0; index < widget.seats.length; index++) {
              final offset = _seatOffset(index, spec, width, metrics);
              children.add(Positioned(
                left: offset.dx - (metrics.seatWidth / 2),
                top: offset.dy,
                width: metrics.seatWidth,
                height: metrics.seatHeight,
                child: _SeatTile(
                  seat: widget.seats[index],
                  selected: widget.selectedSeatIndex == index && _hiddenMenuSeat != index,
                  activeSpeakerPeerIds: activeSpeakerPeerIds,
                  metrics: metrics,
                  onTap: () => _handleSeatTap(index),
                ),
              ));
            }
            return SizedBox(height: layoutHeight, width: width, child: Stack(clipBehavior: Clip.none, children: children));
          },
        );
      },
    );
  }

  void _handleSeatTap(int index) {
    final seat = widget.seats[index];
    final user = seat.user;
    if (user == null) {
      if (widget.applyOnlyModeEnabled && !widget.canManageSeats && !seat.locked) {
        _hideMenu();
        widget.onApply(index);
        return;
      }
      widget.onSeatTap(index);
    } else {
      _hideMenu();
      widget.onUserTap(index);
    }
  }

  RoomSeat? get _selectedSeat {
    final index = widget.selectedSeatIndex;
    if (index == null || index < 0 || index >= widget.seats.length) return null;
    if (_hiddenMenuSeat == index) return null;
    final seat = widget.seats[index];
    if (seat.user != null) return null;
    return widget.canManageSeats ? seat : null;
  }

  Offset _seatOffset(int index, SeatLayoutSpec spec, double width, _SeatMetrics metrics) {
    if (spec.hasHostSeats && index < spec.topSeatCount) {
      final x = _compactHostSeatX(index: index, hostCount: spec.topSeatCount, width: width, metrics: metrics);
      return Offset(x, 0);
    }
    final start = spec.hasHostSeats ? spec.topSeatCount : 0;
    final gridIndex = index - start;
    final row = gridIndex ~/ spec.columns;
    final column = gridIndex % spec.columns;
    final cell = width / spec.columns;
    final topOffset = spec.hasHostSeats ? metrics.rowHeight : 0.0;
    return Offset((cell * column) + (cell / 2), topOffset + (row * metrics.rowHeight));
  }

  double _compactHostSeatX({required int index, required int hostCount, required double width, required _SeatMetrics metrics}) {
    if (hostCount <= 1) return width / 2;
    final centerGap = (metrics.seatWidth + (metrics.seatWidth * 0.18)).clamp(metrics.seatWidth + 8, metrics.seatWidth + 18).toDouble();
    final totalSpan = centerGap * (hostCount - 1);
    final firstX = (width / 2) - (totalSpan / 2);
    return firstX + (centerGap * index);
  }
}

class _SeatMetrics {
  const _SeatMetrics({required this.seatWidth, required this.seatHeight, required this.rowHeight, required this.avatarSize, required this.avatarShellSize, required this.labelHeight, required this.framePadding, required this.nameFontSize, required this.emptyFontSize, required this.badgeSize});

  final double seatWidth;
  final double seatHeight;
  final double rowHeight;
  final double avatarSize;
  final double avatarShellSize;
  final double labelHeight;
  final double framePadding;
  final double nameFontSize;
  final double emptyFontSize;
  final double badgeSize;

  static _SeatMetrics forLayout({required double width, required SeatLayoutSpec spec, required int totalSeats}) {
    final maxColumns = spec.columns > spec.topSeatCount ? spec.columns : spec.topSeatCount;
    final cellWidth = width / maxColumns.clamp(1, 8);
    final dense = totalSeats >= 20 || spec.columns >= 5;
    final medium = totalSeats >= 12 || spec.columns >= 4;
    final avatar = (cellWidth * (dense ? 0.54 : medium ? 0.58 : 0.62)).clamp(dense ? 38.0 : 44.0, dense ? 47.0 : 54.0).toDouble();
    final shell = avatar + (dense ? 9 : 12);
    final seatWidth = cellWidth.clamp(54.0, dense ? 66.0 : 78.0).toDouble();
    final labelHeight = dense ? 15.5 : 18.0;
    final seatHeight = shell + labelHeight + (dense ? 5 : 7);
    return _SeatMetrics(seatWidth: seatWidth, seatHeight: seatHeight, rowHeight: seatHeight + (dense ? 4 : 7), avatarSize: avatar, avatarShellSize: shell, labelHeight: labelHeight, framePadding: dense ? 10 : 14, nameFontSize: dense ? 8.6 : 9.6, emptyFontSize: dense ? 7.6 : 8.6, badgeSize: dense ? 14.5 : 16.5);
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({required this.seat, required this.selected, required this.activeSpeakerPeerIds, required this.metrics, required this.onTap});

  final RoomSeat seat;
  final bool selected;
  final Set<String> activeSpeakerPeerIds;
  final _SeatMetrics metrics;
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
          _SeatAvatar(seat: seat, selected: selected, activeSpeakerPeerIds: activeSpeakerPeerIds, metrics: metrics),
          SizedBox(height: metrics.seatHeight < 72 ? 1.5 : 3),
          SizedBox(height: metrics.labelHeight, child: user == null ? _EmptySeatLabel(index: seat.index, metrics: metrics) : _UserSeatLabel(user: user, index: seat.index, metrics: metrics)),
        ],
      ),
    );
  }
}

class _SeatAvatar extends StatelessWidget {
  const _SeatAvatar({required this.seat, required this.selected, required this.activeSpeakerPeerIds, required this.metrics});

  final RoomSeat seat;
  final bool selected;
  final Set<String> activeSpeakerPeerIds;
  final _SeatMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final user = seat.user;
    final avatarUrl = user?.avatarUrl?.trim();
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final speaking = _isUserSpeaking(user);
    final equippedFrame = user == null ? null : equippedStoreAvatarFrame(userId: user.id, assetPath: user.equippedAvatarFrameAssetPath, imageUrl: user.equippedAvatarFrameImageUrl);

    final avatarFrame = RoomAvatarFrameHost(
      frame: equippedFrame,
      size: metrics.avatarSize,
      framePadding: equippedFrame == null ? 0 : metrics.framePadding,
      staticStrokeWidth: equippedFrame == null ? 0 : 2.0,
      child: Container(
        width: metrics.avatarSize,
        height: metrics.avatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: user == null ? Colors.white.withValues(alpha: seat.locked ? 0.07 : 0.11) : null,
          gradient: user == null || hasAvatar ? null : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: user.avatarColors),
          border: Border.all(color: selected ? Colors.white.withValues(alpha: 0.78) : Colors.white.withValues(alpha: 0.12), width: selected ? 1.05 : 0.75),
        ),
        clipBehavior: Clip.antiAlias,
        child: user == null
            ? Center(child: Icon(seat.locked ? Icons.lock_rounded : Icons.add_rounded, color: Colors.white70, size: seat.locked ? metrics.avatarSize * 0.34 : metrics.avatarSize * 0.43))
            : hasAvatar
                ? Image.network(avatarUrl, fit: BoxFit.cover, alignment: Alignment.center, filterQuality: FilterQuality.high, errorBuilder: (context, error, stackTrace) => _SeatAvatarFallback(user: user, metrics: metrics))
                : _SeatAvatarFallback(user: user, metrics: metrics),
      ),
    );

    return SizedBox(
      width: metrics.avatarShellSize,
      height: metrics.avatarShellSize,
      child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
        if (selected) Container(width: metrics.avatarSize + 5, height: metrics.avatarSize + 5, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.82), width: 1.0))),
        SeatSpeakingWave(size: metrics.avatarSize, active: speaking, child: avatarFrame),
        if (user?.selfMuted ?? false) _SeatMuteBadge(color: RoomColors.selfMute, metrics: metrics),
        if (user?.adminMuted ?? false) _SeatMuteBadge(color: RoomColors.coral, glow: RoomColors.coral.withValues(alpha: 0.30), metrics: metrics),
      ]),
    );
  }

  bool _isUserSpeaking(SeatUser? user) {
    if (user == null || user.selfMuted || user.adminMuted) return false;
    final roomId = LiveRoomMediaSignalingService.instance.mediaEngine.roomId;
    final peerId = roomId == null ? '' : '${roomId}_${user.id}'.replaceAll(' ', '_');
    return user.isSpeaking || activeSpeakerPeerIds.contains(peerId);
  }
}

class _SeatMuteBadge extends StatelessWidget {
  const _SeatMuteBadge({required this.color, required this.metrics, this.glow});
  final Color color;
  final _SeatMetrics metrics;
  final Color? glow;
  @override
  Widget build(BuildContext context) => Positioned(
        right: 1,
        bottom: 4,
        child: Container(
          width: metrics.badgeSize,
          height: metrics.badgeSize,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: RoomColors.deep, width: 0.9), boxShadow: glow == null ? null : [BoxShadow(color: glow!, blurRadius: 6, offset: const Offset(0, 2))]),
          child: Icon(Icons.mic_off_rounded, color: Colors.white, size: metrics.badgeSize * 0.52),
        ),
      );
}

class _SeatAvatarFallback extends StatelessWidget {
  const _SeatAvatarFallback({required this.user, required this.metrics});
  final SeatUser user;
  final _SeatMetrics metrics;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: user.avatarColors)),
        child: Center(child: Text(avatarLetter(user.name), style: TextStyle(color: Colors.white, fontSize: metrics.avatarSize * 0.36, fontWeight: FontWeight.w700, height: 1))),
      );
}

class _EmptySeatLabel extends StatelessWidget {
  const _EmptySeatLabel({required this.index, required this.metrics});
  final int index;
  final _SeatMetrics metrics;
  @override
  Widget build(BuildContext context) => Center(child: Text('NO.${index + 1}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.52), fontSize: metrics.emptyFontSize, fontWeight: FontWeight.w600, height: 1)));
}

class _UserSeatLabel extends StatelessWidget {
  const _UserSeatLabel({required this.user, required this.index, required this.metrics});
  final SeatUser user;
  final int index;
  final _SeatMetrics metrics;
  @override
  Widget build(BuildContext context) {
    final chipColor = user.gender == RoomUserGender.female ? RoomColors.coral : RoomColors.aqua;
    return Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
      Container(width: metrics.labelHeight - 4, height: metrics.labelHeight - 4, alignment: Alignment.center, decoration: BoxDecoration(color: chipColor, shape: BoxShape.circle), child: Text('${index + 1}', style: TextStyle(color: Colors.white, fontSize: metrics.nameFontSize * 0.58, fontWeight: FontWeight.w700, height: 1))),
      const SizedBox(width: 3),
      Flexible(child: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: metrics.nameFontSize, fontWeight: FontWeight.w600, height: 1))),
    ]);
  }
}

class _SeatMenu extends StatefulWidget {
  const _SeatMenu({super.key, required this.locked, required this.canManageSeats, required this.onInvite, required this.onSwitch, required this.onLock, required this.onUnlock});
  final bool locked;
  final bool canManageSeats;
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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 190), reverseDuration: const Duration(milliseconds: 125));
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack, reverseCurve: Curves.easeInBack);
    _opacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic));
    _scale = Tween<double>(begin: 0.88, end: 1).animate(curve);
    _slide = Tween<Offset>(begin: const Offset(0, -0.14), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInBack));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.canManageSeats
        ? widget.locked
            ? [_MenuAction('Invite', widget.onInvite), _MenuAction('Unlock', widget.onUnlock)]
            : [_MenuAction('Invite', widget.onInvite), _MenuAction('Switch', widget.onSwitch), _MenuAction('Lock', widget.onLock)]
        : <_MenuAction>[];
    if (actions.isEmpty) return const SizedBox.shrink();
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          alignment: Alignment.topCenter,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const _SeatMenuPointer(),
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              elevation: 7,
              shadowColor: Colors.black.withValues(alpha: 0.13),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFF5F6470).withValues(alpha: 0.75), borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white.withValues(alpha: 0.13)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.13), blurRadius: 10, offset: const Offset(0, 5))]),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    _MenuButton(action: actions[i]),
                    if (i != actions.length - 1) Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 1.8, horizontal: 4), color: Colors.white.withValues(alpha: 0.10)),
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
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

class _MenuAction {
  const _MenuAction(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.action});
  final _MenuAction action;
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: action.onTap,
        child: SizedBox(height: _RoomSeatLayoutState.menuItemHeight, child: Center(child: Text(action.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10.2, fontWeight: FontWeight.w600, height: 1)))),
      );
}
