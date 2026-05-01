import 'package:flutter/material.dart';

import '../../models/create_room_mode.dart';
import '../widgets/create_ui_helpers.dart';

class CreateRoomReadySheet extends StatelessWidget {
  const CreateRoomReadySheet({
    super.key,
    required this.roomName,
    required this.roomId,
    required this.selectedMode,
    required this.selectedLanguage,
    required this.onEditTap,
    required this.onEnterTap,
  });

  final String roomName;
  final String roomId;
  final CreateRoomMode selectedMode;
  final String selectedLanguage;
  final VoidCallback onEditTap;
  final VoidCallback onEnterTap;

  @override
  Widget build(BuildContext context) {
    return CreateSheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CreateSheetHandle(),
          const SizedBox(height: 16),
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                colors: [Color(0xFF12C7B7), Color(0xFF8C5CF6), Color(0xFFE84C72)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8C5CF6).withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Room Ready',
            style: TextStyle(
              color: Color(0xFF251538),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            roomName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF251538).withValues(alpha: 0.72),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _ReadyInfoRow(label: 'Room ID', value: roomId),
          _ReadyInfoRow(label: 'Mode', value: selectedMode.title),
          _ReadyInfoRow(label: 'Language', value: selectedLanguage),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: CreateSecondaryButton(
                  text: 'Edit',
                  icon: Icons.edit_rounded,
                  onTap: onEditTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CreatePrimaryButton(
                  text: 'Enter Room',
                  icon: Icons.login_rounded,
                  onTap: onEnterTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadyInfoRow extends StatelessWidget {
  const _ReadyInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDE3D7)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF251538),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
