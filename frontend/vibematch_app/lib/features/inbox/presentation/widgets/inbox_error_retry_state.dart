import 'package:flutter/material.dart';

class InboxErrorRetryState extends StatelessWidget {
  const InboxErrorRetryState({super.key, required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 18, 24, 32),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFFFCAD7)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE84C72).withValues(alpha: 0.10),
              blurRadius: 28,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEF3),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFCAD7)),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFFE84C72),
                size: 31,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Connection lost',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF251538),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We could not refresh Inbox. Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF7B6A86),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF251538),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
