import 'package:flutter/material.dart';

import '../../models/create_room_mode.dart';

class CreateModeSection extends StatelessWidget {
  const CreateModeSection({
    super.key,
    required this.selectedMode,
    required this.onModeSelected,
  });

  final CreateRoomMode selectedMode;
  final ValueChanged<CreateRoomMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Room mode',
            style: TextStyle(
              color: Color(0xFF251538),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...CreateRoomMode.values.map(
            (mode) => _ModeCard(
              mode: mode,
              selected: mode == selectedMode,
              onTap: () => onModeSelected(mode),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final CreateRoomMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? mode.color.withValues(alpha: 0.11) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? mode.color : const Color(0xFFEDE3D7),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF251538).withValues(alpha: 0.045),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: mode.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(mode.icon, color: mode.color, size: 23),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.title,
                    style: const TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mode.subtitle,
                    style: const TextStyle(
                      color: Color(0xFF7B6A86),
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? mode.color : const Color(0xFFD4C7BB),
            ),
          ],
        ),
      ),
    );
  }
}
