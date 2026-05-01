import 'package:flutter/material.dart';

class CreateRulesCard extends StatelessWidget {
  const CreateRulesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E3),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFFFE4A8)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.security_rounded, color: Color(0xFFC99A3B), size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Backend later controls room access, member approval, image chat, guest messages, audit logs, and room moderation hierarchy.',
              style: TextStyle(
                color: Color(0xFF6A4E18),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
