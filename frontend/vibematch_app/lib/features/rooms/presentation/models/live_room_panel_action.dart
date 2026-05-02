import 'package:flutter/material.dart';

enum LiveRoomPanelActionType {
  gift,
  games,
  vibeSync,
  watch,
  message,
  more,
}

class LiveRoomPanelAction {
  const LiveRoomPanelAction({
    required this.type,
    required this.label,
    required this.icon,
    required this.color,
  });

  final LiveRoomPanelActionType type;
  final String label;
  final IconData icon;
  final Color color;

  static const actions = <LiveRoomPanelAction>[
    LiveRoomPanelAction(
      type: LiveRoomPanelActionType.gift,
      label: 'Gift',
      icon: Icons.card_giftcard_rounded,
      color: Color(0xFFFFC857),
    ),
    LiveRoomPanelAction(
      type: LiveRoomPanelActionType.games,
      label: 'Games',
      icon: Icons.sports_esports_rounded,
      color: Color(0xFF12C7B7),
    ),
    LiveRoomPanelAction(
      type: LiveRoomPanelActionType.vibeSync,
      label: 'VibeSync',
      icon: Icons.favorite_rounded,
      color: Color(0xFFE84C72),
    ),
    LiveRoomPanelAction(
      type: LiveRoomPanelActionType.watch,
      label: 'Watch',
      icon: Icons.play_circle_fill_rounded,
      color: Color(0xFF8C5CF6),
    ),
  ];
}
