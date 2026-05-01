import 'package:flutter/material.dart';

enum CreateRoomMode {
  open('Open', 'Anyone can enter and join the vibe', Icons.public_rounded, Color(0xFF12C7B7)),
  locked('Locked', 'Users need a password or invite', Icons.lock_rounded, Color(0xFFC99A3B)),
  secret('Secret Vibe', 'Private room mode', Icons.visibility_off_rounded, Color(0xFF8C5CF6)),
  vibeSync('Vibe Sync', 'Music-style room with animated mood', Icons.graphic_eq_rounded, Color(0xFFE84C72)),
  membersOnly('Members Only', 'Approved room members can chat', Icons.workspace_premium_rounded, Color(0xFF4A2A63));

  const CreateRoomMode(this.title, this.subtitle, this.icon, this.color);

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}
