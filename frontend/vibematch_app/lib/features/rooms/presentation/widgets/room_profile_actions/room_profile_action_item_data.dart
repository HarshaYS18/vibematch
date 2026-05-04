import 'package:flutter/material.dart';

class RoomProfileActionItemData {
  const RoomProfileActionItemData({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;
}
