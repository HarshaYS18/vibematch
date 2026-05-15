import 'package:flutter/material.dart';

class HomeBackendConnectedStrip extends StatelessWidget {
  const HomeBackendConnectedStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8FAF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB7EFE6)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_done_rounded, color: Color(0xFF12C7B7), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Live room list loaded from backend.',
              style: TextStyle(color: Color(0xFF4A2A63), fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
