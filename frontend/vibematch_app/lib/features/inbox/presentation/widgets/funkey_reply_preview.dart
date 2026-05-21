import 'package:flutter/material.dart';

class FunKeyReplyPreview extends StatelessWidget {
  const FunKeyReplyPreview({
    super.key,
    required this.text,
    required this.onClose,
  });

  final String text;
  final VoidCallback onClose;

  static const _ink = Color(0xFF111114);
  static const _muted = Color(0xFF71717A);
  static const _line = Color(0xFFEDEDEF);
  static const _blue = Color(0xFF3797F0);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 34,
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 9),
            const Icon(Icons.reply_rounded, color: _blue, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Replying',
                    style: TextStyle(
                      color: _blue,
                      fontSize: 10.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: _ink, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}