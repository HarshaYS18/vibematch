import 'package:flutter/material.dart';

import 'create_ui_helpers.dart';

class CreateRoomFormCard extends StatelessWidget {
  const CreateRoomFormCard({
    super.key,
    required this.roomNameController,
    required this.selectedLanguage,
    required this.roomImageSelected,
    required this.onToggleImage,
    required this.onLanguageTap,
  });

  final TextEditingController roomNameController;
  final String selectedLanguage;
  final bool roomImageSelected;
  final VoidCallback onToggleImage;
  final VoidCallback onLanguageTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      padding: const EdgeInsets.all(18),
      decoration: createPanelDecoration(radius: 30),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggleImage,
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: roomImageSelected
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF12C7B7),
                          Color(0xFF8C5CF6),
                          Color(0xFFE84C72),
                        ],
                      )
                    : null,
                color: roomImageSelected ? null : const Color(0xFFF4EEE7),
                border: Border.all(color: const Color(0xFFEDE3D7)),
              ),
              child: Icon(
                roomImageSelected
                    ? Icons.image_rounded
                    : Icons.add_photo_alternate_rounded,
                color: roomImageSelected ? Colors.white : const Color(0xFF7B6A86),
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            roomImageSelected ? 'Room image ready' : 'Tap to add room image',
            style: const TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: roomNameController,
            style: const TextStyle(
              color: Color(0xFF251538),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              labelText: 'Room name',
              labelStyle: const TextStyle(
                color: Color(0xFF7B6A86),
                fontWeight: FontWeight.w700,
              ),
              prefixIcon: const Icon(
                Icons.graphic_eq_rounded,
                color: Color(0xFF12C7B7),
              ),
              filled: true,
              fillColor: const Color(0xFFFAF7F1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: Color(0xFFEDE3D7)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: Color(0xFFEDE3D7)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(
                  color: Color(0xFF12C7B7),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onLanguageTap,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F1),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFEDE3D7)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.language_rounded, color: Color(0xFF8C5CF6)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Room language',
                      style: TextStyle(
                        color: Color(0xFF7B6A86),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    selectedLanguage,
                    style: const TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4A2A63)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
