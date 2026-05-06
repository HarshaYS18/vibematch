import 'package:flutter/material.dart';

import '../widgets/family_redesign_shared.dart';

class DisbandFamilyConfirmationSheet extends StatelessWidget {
  const DisbandFamilyConfirmationSheet({
    super.key,
    required this.familyName,
    required this.onConfirm,
  });

  final String familyName;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return FamilySheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: FamilyRedesignColors.coral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: FamilyRedesignColors.coral.withValues(alpha: 0.22)),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: FamilyRedesignColors.coral, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Disband Family?',
                      style: TextStyle(color: FamilyRedesignColors.ink, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      familyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: FamilyRedesignColors.soft, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'This action will permanently delete the family and remove all members from it. Family chat, ranking progress, family settings, and pending family invites or join requests will no longer be available after confirmation.',
            style: TextStyle(color: FamilyRedesignColors.soft, height: 1.36, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: FamilyRedesignColors.gold.withValues(alpha: 0.18)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: FamilyRedesignColors.gold, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cancel will close this process without making any changes. Confirm will delete the family.',
                    style: TextStyle(color: FamilyRedesignColors.ink, height: 1.28, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FamilySecondaryButton(
                  label: 'Cancel',
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FamilyPrimaryButton(
                  label: 'Confirm',
                  danger: true,
                  onTap: onConfirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
