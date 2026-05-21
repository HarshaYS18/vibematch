import 'package:flutter/material.dart';

import '../../data/live_room_audio_service.dart';
import '../live_room_models.dart';
import 'room_avatar_frames.dart';
import 'room_theme.dart';
import 'seat_speaking_wave.dart';

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
    dismissRoomSeatActionPill();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: LiveRoomAudioService.instance.activeSpeakerPeerIds,
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
        dismissRoomSeatActionPill();
        widget.onApply(index);
        return;
      }
      widget.onSeatTap(index);
    } else {
      dismissRoomSeatActionPill();
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
    return _SeatMetrics(
      seatWidth: seatWidth,
      seatHeight: seatHeight,
      rowHeight: seatHeight + (dense ? 4 : 7),
      avatarSize: avatar,
      avatarShellSize: shell,
      labelHeight: labelHeight,
      framePadding: dense ? 10 : 14,
      nameFontSize: dense ? 8.6 : 9.6,
      emptyFontSize: dense ? 7.6 : 8.6,
      badgeSize: dense ? 14.5 : 16.5,
    );
  }
}
