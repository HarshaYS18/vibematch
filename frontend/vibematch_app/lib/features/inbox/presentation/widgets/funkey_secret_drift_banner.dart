import 'package:flutter/material.dart';

class FunKeySecretDriftBanner extends StatelessWidget {
  const FunKeySecretDriftBanner({
    super.key,
    required this.label,
  });

  final String label;

  static const _orange = Color(0xFFEA580C);
  static const _orangeDark = Color(0xFF7C2D12);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_rounded, color: _orange, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _orangeDark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}