import 'package:flutter/material.dart';

class LiveRoomNavigationController {
  const LiveRoomNavigationController();

  Offset nextBubbleOffset({
    required Offset currentOffset,
    required Offset dragDelta,
    required Size screenSize,
  }) {
    return Offset(
      (currentOffset.dx + dragDelta.dx).clamp(8.0, screenSize.width - 86),
      (currentOffset.dy + dragDelta.dy).clamp(40.0, screenSize.height - 120),
    );
  }

  bool shouldBlockBackAction({
    required bool allowRoomPop,
    required bool didPop,
  }) {
    return !allowRoomPop && !didPop;
  }

  bool canOpenLeaveSheet({
    required bool leaveSheetOpen,
    required bool exitingRoom,
  }) {
    return !leaveSheetOpen && !exitingRoom;
  }

  bool canExitRoom({required bool exitingRoom}) {
    return !exitingRoom;
  }
}
