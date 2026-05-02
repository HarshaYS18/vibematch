import 'package:flutter/material.dart';

import '../../models/live_room_panel_action.dart';
import '../room_theme.dart';

class LiveRoomActionDock extends StatelessWidget {
  const LiveRoomActionDock({
    super.key,
    required this.actions,
    required this.onActionTap,
  });

  final List<LiveRoomPanelAction> actions;
  final ValueChanged<LiveRoomPanelActionType> onActionTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < actions.length; index++) ...[
              _LiveRoomActionButton(
                action: actions[index],
                onTap: () => onActionTap(actions[index].type),
              ),
              if (index != actions.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveRoomActionButton extends StatelessWidget {
  const _LiveRoomActionButton({
    required this.action,
    required this.onTap,
  });

  final LiveRoomPanelAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: action.color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: action.color.withValues(alpha: 0.18),
                  border: Border.all(color: action.color.withValues(alpha: 0.22)),
                ),
                child: Icon(action.icon, color: action.color, size: 18),
              ),
              const SizedBox(height: 5),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LiveRoomCompactMicButton extends StatelessWidget {
  const LiveRoomCompactMicButton({
    super.key,
    required this.muted,
    required this.onTap,
  });

  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: muted
          ? RoomColors.coral.withValues(alpha: 0.16)
          : RoomColors.aqua.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            color: muted ? RoomColors.coral : RoomColors.aqua,
            size: 23,
          ),
        ),
      ),
    );
  }
}
