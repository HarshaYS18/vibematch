import 'package:flutter/material.dart';

import 'family_redesign_shared.dart';

class FamilyEmptyState extends StatelessWidget {
  const FamilyEmptyState({
    super.key,
    required this.onCreateFamily,
    required this.onJoinFamily,
    required this.joinRequestPending,
  });

  final VoidCallback onCreateFamily;
  final VoidCallback onJoinFamily;
  final bool joinRequestPending;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [FamilyRedesignColors.ink, FamilyRedesignColors.coral]),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(Icons.diversity_3_rounded, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 18),
            const Text('No family joined', style: TextStyle(color: FamilyRedesignColors.ink, fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text(
              'Create your own family or request to join the family you are viewing.',
              textAlign: TextAlign.center,
              style: TextStyle(color: FamilyRedesignColors.soft, height: 1.3, fontWeight: FontWeight.w700),
            ),
            if (joinRequestPending) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFF4E8), borderRadius: BorderRadius.circular(18)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hourglass_top_rounded, color: FamilyRedesignColors.gold, size: 18),
                    SizedBox(width: 8),
                    Text('Join request pending', style: TextStyle(color: FamilyRedesignColors.ink, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: FamilySecondaryButton(label: 'Join Family', onTap: joinRequestPending ? () {} : onJoinFamily)),
                const SizedBox(width: 10),
                Expanded(child: FamilyPrimaryButton(label: 'Create Family', onTap: onCreateFamily)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
