import 'package:flutter/material.dart';

import 'family_redesign_shared.dart';

class FamilyEmptyState extends StatelessWidget {
  const FamilyEmptyState({super.key, required this.onCreateFamily});

  final VoidCallback onCreateFamily;

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
              'Create a family with a cover, name, and minimum VIP requirement.',
              textAlign: TextAlign.center,
              style: TextStyle(color: FamilyRedesignColors.soft, height: 1.3, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            FamilyPrimaryButton(label: 'Create Family', onTap: onCreateFamily),
          ],
        ),
      ),
    );
  }
}
