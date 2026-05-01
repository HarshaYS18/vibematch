import 'package:flutter/material.dart';

class CreateHeader extends StatelessWidget {
  const CreateHeader({
    super.key,
    required this.onHelpTap,
  });

  final VoidCallback onHelpTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF12C7B7), Color(0xFF8C5CF6)],
              ),
            ),
            child: const Icon(
              Icons.add_home_work_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Room',
                  style: TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Start your own live vibe',
                  style: TextStyle(
                    color: Color(0xFF7B6A86),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onHelpTap,
            icon: const Icon(
              Icons.help_rounded,
              color: Color(0xFF4A2A63),
            ),
          ),
        ],
      ),
    );
  }
}
