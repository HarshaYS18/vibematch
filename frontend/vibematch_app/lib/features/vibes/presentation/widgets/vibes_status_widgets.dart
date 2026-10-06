import 'package:flutter/material.dart';

import '../../../../core/presentation/vm_async_state.dart';

import '../../models/vibe_models.dart';

class VibesLoadingStrip extends StatelessWidget {
  const VibesLoadingStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return const LinearProgressIndicator(
      minHeight: 3,
      color: Color(0xFF111015),
      backgroundColor: Color(0xFFECE2D8),
    );
  }
}

class VibesErrorCard extends StatelessWidget {
  const VibesErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return VmInlineFailure(
      message: message,
      onRetry: onRetry,
    );
  }
}
class EmptyVibesState extends StatelessWidget {
  const EmptyVibesState({super.key, required this.selectedTab});

  final VibesFeedTab selectedTab;

  @override
  Widget build(BuildContext context) {
    final isFriends = selectedTab == VibesFeedTab.friends;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF111015).withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(isFriends ? Icons.group_rounded : Icons.auto_awesome_rounded, color: const Color(0xFF111015), size: 32),
            ),
            const SizedBox(height: 14),
            Text(
              isFriends ? 'No friend Vibes yet' : 'No Vibes yet',
              style: const TextStyle(color: Color(0xFF111015), fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              isFriends ? 'Follow people to see their Vibes here.' : 'Create the first Vibe or refresh again later.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
